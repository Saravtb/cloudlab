# Runbook operacional

Procedimento para implantar, validar e remover o ambiente. Escrito para ser
executado por qualquer integrante da equipe, sem depender de quem operou
originalmente.

Ambiente: AWS Academy Learner Lab, região `us-east-1`, AWS CloudShell.

## Pré-requisitos

Sessão do Learner Lab ativa, com o indicador ao lado de **AWS** em verde, e o
AWS Management Console aberto na região `us-east-1`.

Não execute `aws configure` e não copie Access Keys. O CloudShell já está
autenticado com as credenciais temporárias do laboratório.

## 1. Obter o repositório

```bash
git clone https://github.com/Saravtb/cloudlab.git
cd cloudlab/infra
chmod +x *.sh
sed -i 's/\r$//' *.sh
export AWS_PAGER=""
```

O `sed` remove quebras de linha do Windows. Sem ele, os scripts falham com
mensagens de erro que não indicam a causa real.

## 2. Criar a camada de dados

```bash
./01-create-rds.sh
```

Cria o security group da aplicação, o security group do banco, o subnet group,
o segredo no Secrets Manager e a instância PostgreSQL. O provisionamento do
banco leva de 10 a 20 minutos.

É possível interromper com `Ctrl+C` sem cancelar a criação, e acompanhar com:

```bash
aws rds describe-db-instances --db-instance-identifier cloudlab-db \
  --query 'DBInstances[0].DBInstanceStatus' --output text
```

Prossiga quando responder `available`.

Para usar outra versão do PostgreSQL: `PG_VERSION=16.13 ./01-create-rds.sh`.

## 3. Publicar e executar o workload

```bash
IMAGE_TAG=v1 ./deploy.sh
```

Constrói a imagem, verifica que o processo não roda como root, publica no ECR,
registra a task definition, cria o cluster e executa a tarefa. Ao final imprime
o endereço IP público e os comandos de verificação.

O repositório do ECR usa tags imutáveis. Para publicar uma versão nova, use
uma tag ainda não utilizada: `IMAGE_TAG=v2 ./deploy.sh`.

## 4. Liberar o acesso do navegador

O script libera automaticamente o endereço de saída do CloudShell, que é
diferente do endereço da máquina de quem opera. Para acessar o painel pelo
navegador, descubra o endereço abrindo `https://checkip.amazonaws.com` **no
navegador** e execute:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id $(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=cloudlab-sg \
    --query 'SecurityGroups[0].GroupId' --output text) \
  --protocol tcp --port 8000 --cidr SEU_ENDERECO/32
```

Se responder `InvalidPermission.Duplicate`, a regra já existe e nada precisa
ser feito.

## 5. Validar

Substitua `IP` pelo endereço impresso pelo `deploy.sh`.

```bash
curl -s http://IP:8000/health
curl -s -X POST http://IP:8000/events \
  -H 'Content-Type: application/json' \
  -d '{"type":"operation.created","source":"cloud-lab","message":"Evento sintetico"}'
curl -s http://IP:8000/events
```

O `/health` deve responder `"status":"healthy"` e `"database":"connected"`.
O `POST` deve responder 201 com um identificador. O `GET` deve listar o evento.

Painel no navegador: `http://IP:8000/`
Documentação da API: `http://IP:8000/docs`

Logs em tempo real:

```bash
aws logs tail /ecs/cloudlab --follow
```

## 6. Remover

```bash
./cleanup.sh
```

Para as tarefas, exclui o cluster, remove as revisões da task definition,
exclui a instância RDS, o subnet group, o segredo, o repositório do ECR, os
dois security groups e o log group. Ao final imprime o inventário residual,
que deve estar vazio em todas as categorias.

A remoção do log group apaga as evidências de log. Salve o que precisar antes.

**Execute o cleanup ao final de cada sessão.** A instância RDS é cobrada
enquanto existir, o ambiente pode não pará-la ao encerrar a sessão, e a AWS
reinicia instâncias paradas após sete dias.

## Diagnóstico

**A tarefa não alcança RUNNING.** O `deploy.sh` já imprime o motivo informado
pelo ECS. As causas mais comuns são o URI da imagem incorreto, a execution role
ausente ou a subnet sem acesso à internet.

**A aplicação responde `degraded` com `database: unavailable`.** O banco não
está acessível. Verifique se a instância está `available` e se o security group
do banco autoriza o security group da aplicação na porta 5432. A aplicação
reconecta sozinha quando o banco volta; não é necessário reiniciar a tarefa.

**O curl a partir do CloudShell não responde, mas o navegador funciona.**
O endereço de saída do CloudShell muda entre sessões, e o security group
autoriza origens `/32`. Reautorize com o novo endereço:

```bash
NEW_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-id $(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=cloudlab-sg \
    --query 'SecurityGroups[0].GroupId' --output text) \
  --protocol tcp --port 8000 --cidr "${NEW_IP}/32"
```

**A tag da imagem já existe.** O repositório é imutável por decisão de
segurança. Use uma tag nova em vez de sobrescrever.

**Erro `$'\r': command not found`.** Os scripts foram salvos com quebras de
linha do Windows. Execute `sed -i 's/\r$//' *.sh`.

**A saída de um comando trava mostrando `:` no final.** É o paginador da AWS
CLI. Pressione `q` para sair, ou execute `export AWS_PAGER=""`.

## Observações registradas durante a operação

O endereço IP público da tarefa muda a cada implantação, porque não há
Application Load Balancer nem endereço elástico associado.

O CloudShell não preserva imagens do Docker entre sessões: após a reciclagem do
ambiente, é necessário reconstruir a imagem localmente antes de comandos que
dependam dela.

Duas tags distintas podem apontar para o mesmo digest quando o conteúdo da
imagem não muda. Isso ocorreu entre as tags `v3` e `v4`, que diferiam apenas
por uma variável de ambiente da task definition, não pela imagem.
