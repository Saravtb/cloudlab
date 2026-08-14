# Inventário de recursos

Recursos criados pelos scripts de `/infra` na conta sandbox do AWS Academy
Learner Lab, região `us-east-1`.

O identificador da conta foi omitido conforme a restrição de não documentar
identificadores desnecessários. Os identificadores de recursos abaixo
correspondem à última implantação e mudam a cada execução.

## Convenção de nomes

Todos os recursos usam o prefixo `cloudlab`, o que permite localizá-los pelo
Tag Editor e confirmar a remoção completa.

## Recursos por serviço

| Serviço | Recurso | Identificador | Criado por |
| --- | --- | --- | --- |
| Amazon ECR | Repositório privado | `cloudlab-events` | `deploy.sh` |
| Amazon ECS | Cluster | `cloudlab-cluster` | `deploy.sh` |
| Amazon ECS | Task definition | `cloudlab-task` | `deploy.sh` |
| Amazon ECS | Tarefa autônoma | gerada a cada execução | `deploy.sh` |
| Amazon RDS | Instância PostgreSQL | `cloudlab-db` | `01-create-rds.sh` |
| Amazon RDS | Subnet group | `cloudlab-db-subnets` | `01-create-rds.sh` |
| Secrets Manager | Segredo | `cloudlab/db` | `01-create-rds.sh` |
| Amazon EC2 | Security group da aplicação | `cloudlab-sg` | `01-create-rds.sh` |
| Amazon EC2 | Security group do banco | `cloudlab-db-sg` | `01-create-rds.sh` |
| Amazon CloudWatch | Log group | `/ecs/cloudlab` | `deploy.sh` |

## Recursos preexistentes utilizados

Não são criados nem removidos pelos scripts.

| Recurso | Origem |
| --- | --- |
| VPC padrão e suas subnets | Fornecida pela conta |
| Role `LabRole` | Pré-criada pelo Learner Lab |

## Configuração de cada recurso

**Repositório ECR.** Privado, com tags imutáveis, varredura de vulnerabilidades
na publicação e criptografia AES-256.

**Task definition.** Fargate, Linux X86_64, modo de rede `awsvpc`, 256 unidades
de CPU e 512 MB de memória. Execution role e task role apontam para `LabRole`.
Porta 8000 em TCP. Log driver `awslogs`. Campo `secrets` referenciando o ARN do
segredo sob o nome `DB_SECRET`.

**Instância RDS.** `db.t3.micro`, PostgreSQL 16.14, 20 GiB de armazenamento
gp2, zona de disponibilidade única, sem acesso público, sem retenção de
backups, sem Enhanced Monitoring e sem criptografia em repouso.

**Security group da aplicação.** Entrada permitida apenas em TCP 8000, com
origens `/32` correspondentes aos endereços de quem opera. Saída padrão.

**Security group do banco.** Entrada permitida apenas em TCP 5432, com origem
definida pelo security group da aplicação. Nenhum bloco CIDR autorizado.

**Log group.** Retenção de 7 dias.

**Segredo.** JSON com usuário, senha, nome do banco, endpoint e porta. Senha
gerada aleatoriamente com 24 caracteres.

## Recursos deliberadamente não criados

| Recurso | Motivo |
| --- | --- |
| Application Load Balancer | Fora do escopo; sem requisito de endereço estável |
| ECS Service | Sem requisito de disponibilidade contínua; consumiria orçamento |
| Auto Scaling | Sem variação de carga a acompanhar |
| Chave do KMS | Sem requisito de confidencialidade em dados sintéticos |
| Role ou policy própria de IAM | Não permitido pelo Learner Lab |
| Dashboard e alarmes do CloudWatch | Fora do escopo desta etapa |

## Verificação de remoção

Após executar `cleanup.sh`, o inventário residual impresso pelo script deve
retornar vazio para clusters ECS, repositórios ECR, instâncias RDS e segredos.

Verificação complementar pelo console: **Resource Groups & Tag Editor**,
selecionando as regiões `us-east-1` e `us-west-2` e todos os tipos de recurso
suportados. Os recursos com prefixo `cloudlab` não devem aparecer.

O termo de remoção está registrado em `evidence/v1.1/25-cleanup.txt`.
