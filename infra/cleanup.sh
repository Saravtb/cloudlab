#!/usr/bin/env bash
#
# Projeto 1 - AWS CloudLab
# Remocao dos recursos criados por deploy.sh.
#
# Execute antes de encerrar o Learner Lab. Recursos em execucao continuam
# consumindo o orcamento do laboratorio.
#
set -uo pipefail   # sem -e: a limpeza deve seguir mesmo se um recurso ja nao existir

PROJECT="cloudlab"
REGION="${AWS_REGION:-us-east-1}"

REPO_NAME="${PROJECT}-events"
CLUSTER_NAME="${PROJECT}-cluster"
TASK_FAMILY="${PROJECT}-task"
SG_NAME="${PROJECT}-sg"
LOG_GROUP="/ecs/${PROJECT}"

export AWS_REGION="$REGION"
export AWS_DEFAULT_REGION="$REGION"

step() { echo; echo "=== $* ==="; }

# --------------------------------------------------------------------------
step "1. Parando as tarefas do cluster"
TASKS="$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --query 'taskArns' --output text 2>/dev/null)"
if [ -n "$TASKS" ] && [ "$TASKS" != "None" ]; then
  for TASK in $TASKS; do
    echo "Parando ${TASK}"
    aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$TASK" >/dev/null 2>&1
  done
  echo "Aguardando o encerramento..."
  aws ecs wait tasks-stopped --cluster "$CLUSTER_NAME" --tasks $TASKS 2>/dev/null
  echo "Tarefas paradas."
else
  echo "Nenhuma tarefa em execucao."
fi

# --------------------------------------------------------------------------
step "2. Excluindo o cluster"
aws ecs delete-cluster --cluster "$CLUSTER_NAME" >/dev/null 2>&1 \
  && echo "Cluster ${CLUSTER_NAME} excluido." \
  || echo "Cluster ${CLUSTER_NAME} nao encontrado."

# --------------------------------------------------------------------------
step "3. Removendo as revisoes da Task Definition"
REVISIONS="$(aws ecs list-task-definitions --family-prefix "$TASK_FAMILY" \
  --query 'taskDefinitionArns' --output text 2>/dev/null)"
if [ -n "$REVISIONS" ] && [ "$REVISIONS" != "None" ]; then
  for REV in $REVISIONS; do
    aws ecs deregister-task-definition --task-definition "$REV" >/dev/null 2>&1
    echo "Deregistrada: ${REV}"
  done
else
  echo "Nenhuma revisao encontrada."
fi

# --------------------------------------------------------------------------
step "4. Excluindo o repositorio do ECR e suas imagens"
aws ecr delete-repository --repository-name "$REPO_NAME" --force >/dev/null 2>&1 \
  && echo "Repositorio ${REPO_NAME} excluido." \
  || echo "Repositorio ${REPO_NAME} nao encontrado."

# --------------------------------------------------------------------------
step "5. Excluindo o Security Group"
# A interface de rede da tarefa demora alguns instantes para ser liberada.
VPC_ID="$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null)"
SG_ID="$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values="$SG_NAME" Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)"

if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
  for ATTEMPT in 1 2 3 4 5 6; do
    if aws ec2 delete-security-group --group-id "$SG_ID" >/dev/null 2>&1; then
      echo "Security Group ${SG_NAME} (${SG_ID}) excluido."
      break
    fi
    echo "Ainda em uso pela interface de rede. Nova tentativa em 15s (${ATTEMPT}/6)..."
    sleep 15
  done
else
  echo "Security Group ${SG_NAME} nao encontrado."
fi

# --------------------------------------------------------------------------
step "6. Excluindo o log group"
echo "Atencao: isso apaga as evidencias de log. Salve o que precisar antes."
aws logs delete-log-group --log-group-name "$LOG_GROUP" >/dev/null 2>&1 \
  && echo "Log group ${LOG_GROUP} excluido." \
  || echo "Log group ${LOG_GROUP} nao encontrado."

# --------------------------------------------------------------------------
step "7. Inventario residual"
echo "Clusters ECS:"
aws ecs list-clusters --query 'clusterArns' --output text 2>/dev/null
echo "Repositorios ECR:"
aws ecr describe-repositories --query 'repositories[].repositoryName' --output text 2>/dev/null

echo
echo "=========================================================="
echo " Limpeza concluida."
echo " Confirme no Tag Editor se restou algum recurso cobrado."
echo "=========================================================="
