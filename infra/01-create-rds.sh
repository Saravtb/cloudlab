#!/usr/bin/env bash
#
# Projeto 1 - AWS CloudLab - incremento v1.1
# Cria a camada de dados: security group do banco, subnet group,
# segredo no Secrets Manager e a instancia PostgreSQL no Amazon RDS.
#
# Execute ANTES de deploy.sh. O provisionamento leva de 10 a 20 minutos.
#
#     cd infra
#     chmod +x 01-create-rds.sh
#     ./01-create-rds.sh
#
set -euo pipefail

PROJECT="cloudlab"
REGION="${AWS_REGION:-us-east-1}"

APP_SG_NAME="${PROJECT}-sg"          # security group da task (ECS)
DB_SG_NAME="${PROJECT}-db-sg"        # security group do banco
DB_SUBNET_GROUP="${PROJECT}-db-subnets"
DB_IDENTIFIER="${PROJECT}-db"
DB_NAME="cloudlab"
DB_USER="cloudlab_app"
SECRET_NAME="${PROJECT}/db"
PG_VERSION="${PG_VERSION:-16.14}"

export AWS_REGION="$REGION"
export AWS_DEFAULT_REGION="$REGION"
export AWS_PAGER=""

step() { echo; echo "=== $* ==="; }

# --------------------------------------------------------------------------
step "0. Contexto"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
VPC_ID="$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)"
echo "Conta:  ${ACCOUNT_ID}"
echo "VPC:    ${VPC_ID}"
echo "Engine: postgres ${PG_VERSION}"

# --------------------------------------------------------------------------
# 1. Security group da aplicacao
#    Criado aqui porque o security group do banco precisa referencia-lo.
#    O deploy.sh reaproveita este mesmo grupo.
# --------------------------------------------------------------------------
step "1. Security group da aplicacao (${APP_SG_NAME})"
APP_SG_ID="$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values="$APP_SG_NAME" Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")"

if [ "$APP_SG_ID" = "None" ] || [ -z "$APP_SG_ID" ]; then
  APP_SG_ID="$(aws ec2 create-security-group \
    --group-name "$APP_SG_NAME" \
    --description "Acesso controlado ao workload ${PROJECT}" \
    --vpc-id "$VPC_ID" --query 'GroupId' --output text)"
  echo "Criado: ${APP_SG_ID}"
else
  echo "Reaproveitando: ${APP_SG_ID}"
fi

MY_IP="$(curl -s https://checkip.amazonaws.com | tr -d '\n')"
aws ec2 authorize-security-group-ingress \
  --group-id "$APP_SG_ID" --protocol tcp --port 8000 --cidr "${MY_IP}/32" \
  >/dev/null 2>&1 && echo "Porta 8000 liberada para ${MY_IP}/32." \
  || echo "Regra para ${MY_IP}/32 ja existia."

# --------------------------------------------------------------------------
# 2. Security group do banco
#    A origem e o SECURITY GROUP da task, nao um endereco IP.
#    Nenhum CIDR e autorizado: o banco so aceita conexao de quem
#    pertence ao grupo da aplicacao.
# --------------------------------------------------------------------------
step "2. Security group do banco (${DB_SG_NAME})"
DB_SG_ID="$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values="$DB_SG_NAME" Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")"

if [ "$DB_SG_ID" = "None" ] || [ -z "$DB_SG_ID" ]; then
  DB_SG_ID="$(aws ec2 create-security-group \
    --group-name "$DB_SG_NAME" \
    --description "Acesso ao PostgreSQL somente a partir da task ${PROJECT}" \
    --vpc-id "$VPC_ID" --query 'GroupId' --output text)"
  echo "Criado: ${DB_SG_ID}"
else
  echo "Reaproveitando: ${DB_SG_ID}"
fi

aws ec2 authorize-security-group-ingress \
  --group-id "$DB_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=5432,ToPort=5432,UserIdGroupPairs=[{GroupId=${APP_SG_ID},Description=\"Somente a task ECS\"}]" \
  >/dev/null 2>&1 && echo "Porta 5432 liberada apenas para ${APP_SG_ID}." \
  || echo "Regra de origem ${APP_SG_ID} ja existia."

# --------------------------------------------------------------------------
step "3. Subnet group do banco"
SUBNET_IDS="$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[0:3].SubnetId' --output text)"
echo "Subnets: ${SUBNET_IDS}"

aws rds create-db-subnet-group \
  --db-subnet-group-name "$DB_SUBNET_GROUP" \
  --db-subnet-group-description "Subnets da VPC padrao para ${PROJECT}" \
  --subnet-ids $SUBNET_IDS >/dev/null 2>&1 \
  && echo "Subnet group criado." \
  || echo "Subnet group ja existia."

# --------------------------------------------------------------------------
# 4. Senha e segredo
#    A senha e gerada aleatoriamente e nunca aparece em arquivo do projeto.
#    Somente o ARN do segredo sera referenciado na task definition.
# --------------------------------------------------------------------------
step "4. Segredo no Secrets Manager (${SECRET_NAME})"
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" >/dev/null 2>&1; then
  echo "Segredo ja existe. Reaproveitando a senha armazenada."
  DB_PASSWORD="$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" \
    --query 'SecretString' --output text | python3 -c 'import json,sys; print(json.load(sys.stdin)["password"])')"
else
  DB_PASSWORD="$(openssl rand -base64 24 | tr -d '/@" \n' | cut -c1-24)"
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --description "Credenciais do PostgreSQL do projeto ${PROJECT}" \
    --secret-string "{\"username\":\"${DB_USER}\",\"password\":\"${DB_PASSWORD}\",\"dbname\":\"${DB_NAME}\"}" \
    >/dev/null
  echo "Segredo criado com senha aleatoria de 24 caracteres."
fi

SECRET_ARN="$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" \
  --query 'ARN' --output text)"
echo "ARN do segredo obtido."

# --------------------------------------------------------------------------
# 5. Instancia RDS
#    db.t3.micro, single-AZ, 20 GB gp2, SEM acesso publico.
#    Enhanced monitoring desabilitado (nao suportado no Learner Lab).
# --------------------------------------------------------------------------
step "5. Instancia PostgreSQL (${DB_IDENTIFIER})"
if aws rds describe-db-instances --db-instance-identifier "$DB_IDENTIFIER" >/dev/null 2>&1; then
  echo "Instancia ja existe. Pulando a criacao."
else
  aws rds create-db-instance \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version "$PG_VERSION" \
    --master-username "$DB_USER" \
    --master-user-password "$DB_PASSWORD" \
    --db-name "$DB_NAME" \
    --allocated-storage 20 \
    --storage-type gp2 \
    --vpc-security-group-ids "$DB_SG_ID" \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --no-publicly-accessible \
    --no-multi-az \
    --backup-retention-period 0 \
    --no-auto-minor-version-upgrade \
    --no-deletion-protection \
    --tags Key=Project,Value="$PROJECT" Key=Environment,Value=lab \
    >/dev/null
  echo "Criacao solicitada."
fi

echo
echo "Aguardando o banco ficar disponivel (10 a 20 minutos)..."
echo "Pode interromper com Ctrl+C e acompanhar depois com:"
echo "  aws rds describe-db-instances --db-instance-identifier ${DB_IDENTIFIER} --query 'DBInstances[0].DBInstanceStatus' --output text"
echo

aws rds wait db-instance-available --db-instance-identifier "$DB_IDENTIFIER"

DB_HOST="$(aws rds describe-db-instances --db-instance-identifier "$DB_IDENTIFIER" \
  --query 'DBInstances[0].Endpoint.Address' --output text)"

# --------------------------------------------------------------------------
step "6. Registrando o endpoint no segredo"
aws secretsmanager put-secret-value \
  --secret-id "$SECRET_NAME" \
  --secret-string "{\"username\":\"${DB_USER}\",\"password\":\"${DB_PASSWORD}\",\"dbname\":\"${DB_NAME}\",\"host\":\"${DB_HOST}\",\"port\":\"5432\"}" \
  >/dev/null
echo "Endpoint gravado no segredo."

echo
echo "=========================================================="
echo " Camada de dados pronta"
echo "=========================================================="
echo " Instancia : ${DB_IDENTIFIER} (db.t3.micro, single-AZ, 20 GB)"
echo " Endpoint  : ${DB_HOST}"
echo " Acesso    : somente do security group ${APP_SG_ID}"
echo " Publico   : nao"
echo " Segredo   : ${SECRET_NAME}"
echo
echo " Proximo passo: ./deploy.sh"
echo " Ao terminar o projeto: ./cleanup.sh remove tambem o banco."
echo "=========================================================="
