#!/usr/bin/env bash
#
# Projeto 1 - AWS CloudLab - incremento v1.1
# Remocao de todos os recursos criados por 01-create-rds.sh e deploy.sh.
#
# ATENCAO: a instancia RDS e cobrada enquanto existir. O ambiente do
# Learner Lab pode NAO para-la ao encerrar a sessao, e uma instancia
# parada e religada automaticamente pela AWS apos 7 dias. Por isso este
# script exclui a instancia em vez de apenas para-la.
#
set -uo pipefail   # sem -e: a limpeza segue mesmo se um recurso ja nao existir

PROJECT="cloudlab"
REGION="${AWS_REGION:-us-east-1}"

REPO_NAME="${PROJECT}-events"
CLUSTER_NAME="${PROJECT}-cluster"
TASK_FAMILY="${PROJECT}-task"
APP_SG_NAME="${PROJECT}-sg"
DB_SG_NAME="${PROJECT}-db-sg"
DB_IDENTIFIER="${PROJECT}-db"
DB_SUBNET_GROUP="${PROJECT}-db-subnets"
SECRET_NAME="${PROJECT}/db"
LOG_GROUP="/ecs/${PROJECT}"

export AWS_REGION="$REGION"
export AWS_DEFAULT_REGION="$REGION"
export AWS_PAGER=""

step() { echo; echo "=== $* ==="; }

# --------------------------------------------------------------------------
step "1. Parando as tarefas"
TASKS="$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --query 'taskArns' --output text 2>/dev/null)"
if [ -n "$TASKS" ] && [ "$TASKS" != "None" ]; then
  for TASK in $TASKS; do
    aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$TASK" >/dev/null 2>&1
    echo "Parando ${TASK}"
  done
  aws ecs wait tasks-stopped --cluster "$CLUSTER_NAME" --tasks $TASKS 2>/dev/null
  echo "Tarefas paradas."
else
  echo "Nenhuma tarefa em execucao."
fi

# --------------------------------------------------------------------------
step "2. Excluindo o cluster"
aws ecs delete-cluster --cluster "$CLUSTER_NAME" >/dev/null 2>&1 \
  && echo "Cluster excluido." || echo "Cluster nao encontrado."

# --------------------------------------------------------------------------
step "3. Removendo as revisoes da Task Definition"
REVISIONS="$(aws ecs list-task-definitions --family-prefix "$TASK_FAMILY" \
  --query 'taskDefinitionArns' --output text 2>/dev/null)"
if [ -n "$REVISIONS" ] && [ "$REVISIONS" != "None" ]; then
  for REV in $REVISIONS; do
    aws ecs deregister-task-definition --task-definition "$REV" >/dev/null 2>&1
    echo "Deregistrada: ${REV##*/}"
  done
else
  echo "Nenhuma revisao encontrada."
fi

# --------------------------------------------------------------------------
step "4. Excluindo a instancia RDS"
if aws rds describe-db-instances --db-instance-identifier "$DB_IDENTIFIER" >/dev/null 2>&1; then
  aws rds delete-db-instance \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --skip-final-snapshot \
    --delete-automated-backups \
    >/dev/null 2>&1
  echo "Exclusao solicitada. Aguardando (pode levar alguns minutos)..."
  aws rds wait db-instance-deleted --db-instance-identifier "$DB_IDENTIFIER" 2>/dev/null
  echo "Instancia ${DB_IDENTIFIER} excluida."
else
  echo "Instancia ${DB_IDENTIFIER} nao encontrada."
fi

# --------------------------------------------------------------------------
step "5. Excluindo o subnet group"
aws rds delete-db-subnet-group --db-subnet-group-name "$DB_SUBNET_GROUP" >/dev/null 2>&1 \
  && echo "Subnet group excluido." || echo "Subnet group nao encontrado."

# --------------------------------------------------------------------------
step "6. Excluindo o segredo"
aws secretsmanager delete-secret --secret-id "$SECRET_NAME" \
  --force-delete-without-recovery >/dev/null 2>&1 \
  && echo "Segredo excluido." || echo "Segredo nao encontrado."

# --------------------------------------------------------------------------
step "7. Excluindo o repositorio do ECR"
aws ecr delete-repository --repository-name "$REPO_NAME" --force >/dev/null 2>&1 \
  && echo "Repositorio excluido." || echo "Repositorio nao encontrado."

# --------------------------------------------------------------------------
# 8. Security groups
#    O grupo do banco depende do grupo da aplicacao, entao a ordem importa:
#    primeiro o do banco, depois o da aplicacao.
# --------------------------------------------------------------------------
step "8. Excluindo os security groups"
VPC_ID="$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null)"

delete_sg() {
  local NAME="$1"
  local SG_ID
  SG_ID="$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values="$NAME" Name=vpc-id,Values="$VPC_ID" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)"
  if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
    echo "${NAME}: nao encontrado."
    return
  fi
  for ATTEMPT in 1 2 3 4 5 6; do
    if aws ec2 delete-security-group --group-id "$SG_ID" >/dev/null 2>&1; then
      echo "${NAME} (${SG_ID}) excluido."
      return
    fi
    echo "${NAME}: ainda em uso, nova tentativa em 15s (${ATTEMPT}/6)..."
    sleep 15
  done
  echo "${NAME}: nao foi possivel excluir. Verifique no console."
}

delete_sg "$DB_SG_NAME"
delete_sg "$APP_SG_NAME"

# --------------------------------------------------------------------------
step "9. Excluindo o log group"
echo "Atencao: isso apaga as evidencias de log. Salve o que precisar antes."
aws logs delete-log-group --log-group-name "$LOG_GROUP" >/dev/null 2>&1 \
  && echo "Log group excluido." || echo "Log group nao encontrado."

# --------------------------------------------------------------------------
step "10. Inventario residual"
echo "Clusters ECS:"
aws ecs list-clusters --query 'clusterArns' --output text 2>/dev/null
echo "Repositorios ECR:"
aws ecr describe-repositories --query 'repositories[].repositoryName' --output text 2>/dev/null
echo "Instancias RDS:"
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output text 2>/dev/null
echo "Segredos:"
aws secretsmanager list-secrets --query 'SecretList[].Name' --output text 2>/dev/null

echo
echo "=========================================================="
echo " Limpeza concluida."
echo " Confirme no Tag Editor se restou algum recurso cobrado."
echo "=========================================================="
