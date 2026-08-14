# Evidências operacionais — baseline v1.0

Ambiente: AWS Academy Learner Lab, região `us-east-1`.
Workload: `cloudlab-events` v1.0.0, executado no Amazon ECS com AWS Fargate.
Data da coleta: 13–14 de agosto de 2026.

O identificador de 12 dígitos da conta foi substituído por `<ACCOUNT_ID>` nos
arquivos de texto, conforme a restrição de não versionar identificadores
desnecessários da conta.

## Inventário

| Arquivo | O que comprova |
| --- | --- |
| `01-imagem-local-e-nao-root.png` | Imagem construída localmente (`v1`, 158 MB) e processo executando com `uid=10001`, não root. |
| `02-ecr-digest-cli.png` | Tag `v1` e digest `sha256:9c7b28…` no repositório privado do ECR. |
| `03-task-running-cli.png` | Task em `RUNNING`, launch type `FARGATE`, 256 CPU / 512 MB, imagem resolvida a partir do ECR. |
| `04-endpoints-cli.png` | Contrato funcional respondendo na nuvem: `GET /`, `GET /health` com horário, `POST /events` com `id` e `status`. |
| `05-cloudwatch-logs-cli.png` | Log estruturado em JSON no CloudWatch, com `id`, `type`, `source` e `status`, mais o log de acesso do servidor. |
| `06-mascaramento-account-id.png` | Verificação de que nenhum arquivo de evidência contém o número da conta. |
| `07-ecr-console.png` | Repositório privado `cloudlab-events` com uma imagem, tag `v1`, digest e tamanho. |
| `08a-ecs-task-lista.png` | Task ativa no cluster `cloudlab-cluster`, definição `cloudlab-task:1`. |
| `08b-ecs-task-fargate.png` | Dimensionamento `.25 vCPU` / `.5 GiB`, plataforma Fargate 1.4.0, IP privado e público, AZ `us-east-1e`. |
| `09a-swagger-contrato.png` | Documentação OpenAPI gerada pela aplicação, com as três rotas exigidas. |
| `09b-swagger-request.png` | Corpo da requisição no formato do evento sintético especificado. |
| `09c-swagger-response-202.png` | Resposta `202 Accepted` com `id` gerado e `status: received`. |
| `10a-security-groups-lista.png` | Security group `cloudlab-sg` criado na VPC padrão. |
| `10b-security-group-regras.png` | Regras de entrada: apenas TCP 8000, origens `/32`, sem `0.0.0.0/0` e sem portas administrativas. |

## Termo de cleanup

Os recursos desta versão foram removidos ao final da sessão de 13 de agosto,
com inventário residual vazio. O termo de remoção consolidado do projeto,
correspondente à última execução do `cleanup.sh`, está em
`evidence/v1.1/25-cleanup.txt`.

## Observação operacional

O endereço IP de saída do AWS CloudShell muda entre sessões. Como o security
group autoriza origens `/32`, o acesso a partir do CloudShell exige
reautorização quando a sessão é reiniciada, mesmo com a task saudável. Isso
foi observado durante a coleta e está registrado no runbook.
