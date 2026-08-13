#!/usr/bin/env bash
#
# Projeto 1 - AWS CloudLab
# Implantacao reproduzivel do workload minimo no Amazon ECS com AWS Fargate.
#
# Uso, a partir do AWS CloudShell:
#     cd infra
#     chmod +x deploy.sh cleanup.sh
#     ./deploy.sh
#
# Pre-requisito: diretorio ../app com main.py, requirements.txt e Dockerfile.
#
set -euo pipefail

# --------------------------------------------------------------------------
# Parametros do projeto
# --------------------------------------------------------------------------
PROJECT="cloudlab"
REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${IMAGE_TAG:-v1}"

REPO_NAME="${PROJECT}-events"
CLUSTER_NAME="${PROJECT}-cluster"
TASK_FAMILY="${PROJECT}-task"
CONTAINER_NAME="${PROJECT}-events"
SG_NAME="${PROJECT}-sg"
LOG_GROUP="/ecs/${PROJECT}"

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../app" && pwd)"

export AWS_REGION="$REGION"
export AWS_DEFAULT_REGION="$REGION"

step() { echo; echo "=== $* ==="; }

# --------------------------------------------------------------------------
# 0. Identidade e contexto
# --------------------------------------------------------------------------
step "0. Conferindo a identidade do laboratorio"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
LAB_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/LabRole"
echo "Conta:   ${ACCOUNT_ID}"
echo "Regiao:  ${REGION}"
echo "Imagem:  ${REPO_NAME}:${IMAGE_TAG}"

# --------------------------------------------------------------------------
# 1. Repositorio privado no Amazon ECR
# --------------------------------------------------------------------------
step "1. Criando o repositorio no Amazon ECR"
if aws ecr describe-repositories --repository-names "$REPO_NAME" >/dev/null 2>&1; then
  echo "Repositorio ${REPO_NAME} ja existe. Reaproveitando."
else
  aws ecr create-repository \
    --repository-name "$REPO_NAME" \
    --image-tag-mutability IMMUTABLE \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 \
    >/dev/null
  echo "Repositorio ${REPO_NAME} criado (privado, tag imutavel, AES256, scan on push)."
fi

ECR_URI="$(aws ecr describe-repositories \
  --repository-names "$REPO_NAME" \
  --query 'repositories[0].repositoryUri' --output text)"
ECR_REGISTRY="${ECR_URI%%/*}"
echo "URI: ${ECR_URI}"

# --------------------------------------------------------------------------
# 2. Build e push da imagem
# --------------------------------------------------------------------------
step "2. Construindo a imagem"
echo "Contexto: ${APP_DIR}"
docker build --platform linux/amd64 -t "${REPO_NAME}:${IMAGE_TAG}" "$APP_DIR"

step "2.1 Verificando que o processo nao roda como root"
docker run --rm "${REPO_NAME}:${IMAGE_TAG}" id

step "2.2 Autenticando o Docker no ECR"
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

step "2.3 Enviando a imagem"
docker tag "${REPO_NAME}:${IMAGE_TAG}" "${ECR_URI}:${IMAGE_TAG}"
docker push "${ECR_URI}:${IMAGE_TAG}"

IMAGE_DIGEST="$(aws ecr describe-images \
  --repository-name "$REPO_NAME" \
  --image-ids imageTag="$IMAGE_TAG" \
  --query 'imageDetails[0].imageDigest' --output text)"
echo "Digest: ${IMAGE_DIGEST}"

# --------------------------------------------------------------------------
# 3. CloudWatch Logs
# --------------------------------------------------------------------------
step "3. Criando o log group no CloudWatch"
aws logs create-log-group --log-group-name "$LOG_GROUP" 2>/dev/null \
  && echo "Log group ${LOG_GROUP} criado." \
  || echo "Log group ${LOG_GROUP} ja existe."

aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7
echo "Retencao definida em 7 dias (controle de custo)."

# --------------------------------------------------------------------------
# 4. Task Definition
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
        { "name": "SERVICE_VERSION", "value": "1.0.0" }
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
# 5. Cluster
# --------------------------------------------------------------------------
step "5. Criando o cluster ECS"
aws ecs create-cluster --cluster-name "$CLUSTER_NAME" >/dev/null
echo "Cluster ${CLUSTER_NAME} pronto."

# --------------------------------------------------------------------------
# 6. Rede: VPC padrao, subnets e Security Group
# --------------------------------------------------------------------------
step "6. Configurando a rede"
VPC_ID="$(aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)"

SUBNETS="$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC_ID" Name=map-public-ip-on-launch,Values=true \
  --query 'Subnets[0:2].SubnetId' --output text | tr '\t' ',')"

echo "VPC:     ${VPC_ID}"
echo "Subnets: ${SUBNETS}"

MY_IP="$(curl -s https://checkip.amazonaws.com | tr -d '\n')"
echo "IP de origem autorizado: ${MY_IP}/32"

SG_ID="$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values="$SG_NAME" Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")"

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
  SG_ID="$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "Acesso controlado ao workload ${PROJECT}" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' --output text)"
  echo "Security Group ${SG_NAME} criado: ${SG_ID}"
fi

# Regra de entrada apenas para o IP atual, apenas na porta da aplicacao.
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 8000 --cidr "${MY_IP}/32" \
  >/dev/null 2>&1 && echo "Regra TCP 8000 liberada para ${MY_IP}/32." \
  || echo "Regra TCP 8000 para ${MY_IP}/32 ja existia."

# --------------------------------------------------------------------------
# 7. Execucao da tarefa
# --------------------------------------------------------------------------
step "7. Executando a tarefa no AWS Fargate"
TASK_ARN="$(aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --launch-type FARGATE \
  --task-definition "$TASK_DEF_ARN" \
  --count 1 \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SG_ID}],assignPublicIp=ENABLED}" \
  --query 'tasks[0].taskArn' --output text)"
echo "Task: ${TASK_ARN}"

echo "Aguardando o estado RUNNING..."
aws ecs wait tasks-running --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" || {
  echo
  echo "A tarefa nao alcancou RUNNING. Motivo informado pelo ECS:"
  aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" \
    --query 'tasks[0].{stopCode:stopCode,stoppedReason:stoppedReason,containers:containers[].reason}' \
    --output json
  exit 1
}

# --------------------------------------------------------------------------
# 8. Endereco publico
# --------------------------------------------------------------------------
step "8. Descobrindo o endereco publico"
ENI_ID="$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value | [0]" \
  --output text)"

PUBLIC_IP="$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text)"

echo
echo "=========================================================="
echo " Implantacao concluida"
echo "=========================================================="
echo " Imagem  : ${ECR_URI}:${IMAGE_TAG}"
echo " Digest  : ${IMAGE_DIGEST}"
echo " Cluster : ${CLUSTER_NAME}"
echo " Logs    : ${LOG_GROUP}"
echo " IP      : ${PUBLIC_IP}"
echo
echo " Endpoints:"
echo "   curl http://${PUBLIC_IP}:8000/"
echo "   curl http://${PUBLIC_IP}:8000/health"
echo "   curl -X POST http://${PUBLIC_IP}:8000/events \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"type\":\"operation.created\",\"source\":\"cloud-lab\",\"message\":\"Evento sintetico para uso academico\"}'"
echo
echo " Logs no CloudWatch:"
echo "   aws logs tail ${LOG_GROUP} --follow"
echo
echo " Ao terminar, execute ./cleanup.sh"
echo "=========================================================="
