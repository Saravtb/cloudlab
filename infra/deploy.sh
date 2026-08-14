#!/usr/bin/env bash
#
# Projeto 1 - AWS CloudLab - incremento v1.2
# Implantacao do workload com persistencia no Amazon RDS.
#
# Pre-requisito: ./01-create-rds.sh executado com sucesso.
#
#     cd infra
#     ./deploy.sh
#
set -euo pipefail

PROJECT="cloudlab"
REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${IMAGE_TAG:-v2}"

REPO_NAME="${PROJECT}-events"
CLUSTER_NAME="${PROJECT}-cluster"
TASK_FAMILY="${PROJECT}-task"
CONTAINER_NAME="${PROJECT}-events"
APP_SG_NAME="${PROJECT}-sg"
LOG_GROUP="/ecs/${PROJECT}"
SECRET_NAME="${PROJECT}/db"

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../app" && pwd)"

export AWS_REGION="$REGION"
export AWS_DEFAULT_REGION="$REGION"
export AWS_PAGER=""

step() { echo; echo "=== $* ==="; }

# --------------------------------------------------------------------------
step "0. Contexto"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
LAB_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/LabRole"
echo "Conta:  ${ACCOUNT_ID}"
echo "Regiao: ${REGION}"
echo "Imagem: ${REPO_NAME}:${IMAGE_TAG}"

# --------------------------------------------------------------------------
step "0.1 Verificando a camada de dados"
SECRET_ARN="$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" \
  --query 'ARN' --output text 2>/dev/null || echo "")"
if [ -z "$SECRET_ARN" ]; then
  echo "Segredo ${SECRET_NAME} nao encontrado."
  echo "Execute ./01-create-rds.sh antes deste script."
  exit 1
fi

DB_STATUS="$(aws rds describe-db-instances --db-instance-identifier "${PROJECT}-db" \
  --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "ausente")"
echo "Banco: ${DB_STATUS}"
if [ "$DB_STATUS" != "available" ]; then
  echo "Aviso: o banco ainda nao esta disponivel."
  echo "A aplicacao subira em modo degradado e reconectara sozinha."
fi

# --------------------------------------------------------------------------
step "1. Repositorio no Amazon ECR"
if aws ecr describe-repositories --repository-names "$REPO_NAME" >/dev/null 2>&1; then
  echo "Repositorio ${REPO_NAME} ja existe."
else
  aws ecr create-repository \
    --repository-name "$REPO_NAME" \
    --image-tag-mutability IMMUTABLE \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 \
    >/dev/null
  echo "Repositorio ${REPO_NAME} criado."
fi

ECR_URI="$(aws ecr describe-repositories --repository-names "$REPO_NAME" \
  --query 'repositories[0].repositoryUri' --output text)"
ECR_REGISTRY="${ECR_URI%%/*}"

if aws ecr describe-images --repository-name "$REPO_NAME" \
     --image-ids imageTag="$IMAGE_TAG" >/dev/null 2>&1; then
  echo "A tag ${IMAGE_TAG} ja existe e o repositorio e imutavel."
  echo "Use IMAGE_TAG=v3 ./deploy.sh para publicar uma nova versao."
  exit 1
fi

# --------------------------------------------------------------------------
step "2. Construindo a imagem"
docker build --platform linux/amd64 -t "${REPO_NAME}:${IMAGE_TAG}" "$APP_DIR"

step "2.1 Verificando que o processo nao roda como root"
docker run --rm "${REPO_NAME}:${IMAGE_TAG}" id

step "2.2 Autenticando no ECR"
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

step "2.3 Enviando a imagem"
docker tag "${REPO_NAME}:${IMAGE_TAG}" "${ECR_URI}:${IMAGE_TAG}"
docker push "${ECR_URI}:${IMAGE_TAG}"

IMAGE_DIGEST="$(aws ecr describe-images --repository-name "$REPO_NAME" \
  --image-ids imageTag="$IMAGE_TAG" \
  --query 'imageDetails[0].imageDigest' --output text)"
echo "Digest: ${IMAGE_DIGEST}"

# --------------------------------------------------------------------------
step "3. CloudWatch Logs"
aws logs create-log-group --log-group-name "$LOG_GROUP" 2>/dev/null \
  && echo "Log group criado." || echo "Log group ja existe."
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7

# --------------------------------------------------------------------------
# 4. Task Definition
#    A senha do banco NAO aparece aqui. O campo "secrets" guarda apenas o ARN
#    do segredo; o ECS resolve o valor no momento de iniciar o container,
#    usando a execution role.
# --------------------------------------------------------------------------
step "4. Registrando a Task Definition"
cat > /tmp/task-definition.json <<JSON
{
  "family": "${TASK_FAMILY}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "runtimePlatform": {
    "operatingSystemFamily": "LINUX",
    "cpuArchitecture": "X86_64"
  },
  "executionRoleArn": "${LAB_ROLE_ARN}",
  "taskRoleArn": "${LAB_ROLE_ARN}",
  "containerDefinitions": [
    {
      "name": "${CONTAINER_NAME}",
      "image": "${ECR_URI}:${IMAGE_TAG}",
      "essential": true,
      "portMappings": [
        { "containerPort": 8000, "protocol": "tcp" }
      ],
      "environment": [
        { "name": "SERVICE_NAME", "value": "${PROJECT}-events" },
        { "name": "SERVICE_VERSION", "value": "1.2.0" }
      ],
      "secrets": [
        { "name": "DB_SECRET", "valueFrom": "${SECRET_ARN}" }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${LOG_GROUP}",
          "awslogs-region": "${REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
JSON

TASK_DEF_ARN="$(aws ecs register-task-definition \
  --cli-input-json file:///tmp/task-definition.json \
  --query 'taskDefinition.taskDefinitionArn' --output text)"
echo "Task Definition: ${TASK_DEF_ARN}"

# --------------------------------------------------------------------------
step "5. Cluster ECS"
aws ecs create-cluster --cluster-name "$CLUSTER_NAME" >/dev/null
echo "Cluster ${CLUSTER_NAME} pronto."

# --------------------------------------------------------------------------
step "6. Rede"
VPC_ID="$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)"
SUBNETS="$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC_ID" Name=map-public-ip-on-launch,Values=true \
  --query 'Subnets[0:2].SubnetId' --output text | tr '\t' ',')"

APP_SG_ID="$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values="$APP_SG_NAME" Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")"

if [ "$APP_SG_ID" = "None" ] || [ -z "$APP_SG_ID" ]; then
  echo "Security group ${APP_SG_NAME} nao encontrado."
  echo "Execute ./01-create-rds.sh, que o cria junto com o grupo do banco."
  exit 1
fi
echo "Security group da aplicacao: ${APP_SG_ID}"

MY_IP="$(curl -s https://checkip.amazonaws.com | tr -d '\n')"
aws ec2 authorize-security-group-ingress \
  --group-id "$APP_SG_ID" --protocol tcp --port 8000 --cidr "${MY_IP}/32" \
  >/dev/null 2>&1 && echo "Porta 8000 liberada para ${MY_IP}/32." \
  || echo "Regra para ${MY_IP}/32 ja existia."

# --------------------------------------------------------------------------
step "7. Executando a tarefa"
TASK_ARN="$(aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --launch-type FARGATE \
  --task-definition "$TASK_DEF_ARN" \
  --count 1 \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${APP_SG_ID}],assignPublicIp=ENABLED}" \
  --query 'tasks[0].taskArn' --output text)"
echo "Task: ${TASK_ARN}"

echo "Aguardando RUNNING..."
aws ecs wait tasks-running --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" || {
  echo
  echo "A tarefa nao alcancou RUNNING:"
  aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" \
    --query 'tasks[0].{stopCode:stopCode,stoppedReason:stoppedReason,containers:containers[].reason}' \
    --output json
  exit 1
}

# --------------------------------------------------------------------------
step "8. Endereco publico"
ENI_ID="$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value | [0]" \
  --output text)"
PUBLIC_IP="$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text)"

echo "Aguardando a aplicacao conectar no banco..."
sleep 20

echo
echo "=========================================================="
echo " Implantacao v1.2 concluida"
echo "=========================================================="
echo " Imagem  : ${ECR_URI}:${IMAGE_TAG}"
echo " Digest  : ${IMAGE_DIGEST}"
echo " Logs    : ${LOG_GROUP}"
echo " IP      : ${PUBLIC_IP}"
echo
echo " Frontend:"
echo "   http://${PUBLIC_IP}:8000/"
echo
echo " Verificacoes:"
echo "   curl http://${PUBLIC_IP}:8000/health"
echo "   curl http://${PUBLIC_IP}:8000/events"
echo "   curl -X POST http://${PUBLIC_IP}:8000/events \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"type\":\"operation.created\",\"source\":\"cloud-lab\",\"message\":\"Evento sintetico\"}'"
echo
echo " Logs: aws logs tail ${LOG_GROUP} --follow"
echo " Ao terminar: ./cleanup.sh"
echo "=========================================================="

curl -s --max-time 10 "http://${PUBLIC_IP}:8000/health" || \
  echo "(sem resposta do CloudShell - confira a regra do security group)"
echo
