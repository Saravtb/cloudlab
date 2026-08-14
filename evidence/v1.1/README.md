# Evidências operacionais — incremento v1.1

Ambiente: AWS Academy Learner Lab, região `us-east-1`.
Workload: `cloudlab-events` no Amazon ECS com AWS Fargate e Amazon RDS PostgreSQL.
Data da coleta: 14 de agosto de 2026.

Identificadores de 12 dígitos da conta foram substituídos por `<ACCOUNT_ID>`.
O endereço IP público de origem das requisições foi substituído por `<IP_LOCAL>`.
O endereço `172.31.93.64` que aparece nos logs é o IP privado do banco dentro
da VPC, não roteável pela internet.

## Arquitetura implantada

Código → imagem → Amazon ECR → Amazon ECS com AWS Fargate → Amazon RDS.
Frontend estático servido pela própria aplicação (mesma origem, sem CORS).
Credenciais do banco no AWS Secrets Manager, injetadas pela execution role.
Logs estruturados em JSON no Amazon CloudWatch pelo driver `awslogs`.

## Inventário

| Arquivo | O que comprova |
| --- | --- |
| `12-persistencia.mp4` | Envio de evento pelo frontend, recarga da página e permanência dos dados: persistência real, não estado em memória. |
| `13-rds-conectividade.png` | Regras de grupo de segurança associadas à instância e zona de disponibilidade. |
| `14-db-sg-origem-security-group.png` | Regra de entrada do banco: PostgreSQL 5432 com origem no *security group* da aplicação, não em CIDR. O banco só aceita conexão de quem pertence ao grupo da task. |
| `15-task-definition-container.png` | Container apontando para a imagem versionada no registro privado do ECR. |
| `16-log-persisted-true.png` | Log estruturado no CloudWatch com `"persisted": true`, confirmando gravação no banco. |
| `17-secrets-task-definition.png` | Bloco `secrets` da task definition: `DB_SECRET` recebe apenas o ARN do Secrets Manager, nunca a senha. Mostra também o `logConfiguration` com o driver `awslogs`. |
| `18-rds-configuracao.png` | Dimensionamento: `db.t3.micro`, PostgreSQL 16.14, 20 GiB gp2, Multi-AZ desabilitado, sem escalabilidade automática e sem Enhanced Monitoring. |
| `19-frontend-evento-registrado.png` | Painel saudável, banco conectado e evento registrado com identificador retornado pela API. |
| `20-frontend-eventos-persistidos.png` | Tabela de eventos lida do banco. Contém registros de 11:25 e de 13:30, anteriores e posteriores à parada do banco às 13:11. |

## Teste de resiliência

A instância RDS foi parada deliberadamente com a aplicação em execução, para
verificar o comportamento diante da indisponibilidade da dependência.

| Arquivo | O que comprova |
| --- | --- |
| `21-degradado-painel.png` | 13:11:44 — selo `degradado`, `banco: unavailable`, com a causa exibida na própria interface. A página continuou sendo servida. |
| `22-degradado-cloudwatch.png` | Logs do incidente: `server closed the connection unexpectedly` e tentativas de reconexão do pool, com `/health` respondendo 200 durante todo o período. |
| `23-recuperado-painel.png` | 13:22:21 — selo `saudável`, `banco: connected`, sem reinício do container. A aplicação reconectou sozinha. |
| `24-rds-reiniciado.png` | Instância novamente disponível após o teste. |

Resultado: a indisponibilidade do banco não derruba a tarefa. O `/health`
reporta o estado degradado com a causa, as rotas de dados respondem 503 com
mensagem explícita e a recuperação é automática quando a dependência volta.

## Decisões visíveis nas evidências

- Processo executa como UID 10001, não root.
- Repositório ECR privado, com tag imutável e varredura na publicação.
- Security group da aplicação libera apenas TCP 8000, com origens `/32`.
- Banco sem acesso público, alcançável somente de dentro da VPC.
- Senha gerada aleatoriamente, armazenada cifrada e nunca versionada.
- Retenção de logs em 7 dias e instância sem backup automático, por decisão
  de custo registrada nos ADRs.
- Criptografia em repouso não habilitada: os dados são sintéticos e
  acadêmicos, sem requisito de confidencialidade.

## Termo de cleanup

| Arquivo | O que comprova |
| --- | --- |
| `25-cleanup.txt` | Saída de `infra/cleanup.sh` com o inventário residual vazio. |
| `25a-cleanup-console.png` | Execução do script no CloudShell, passos 1 a 8. |
| `25b-cleanup-inventario.png` | Passos 9 e 10: inventário residual sem clusters, repositórios, instâncias ou segredos. |

A captura corresponde a uma segunda execução do script, feita para registrar
a evidência; por isso a maioria dos recursos aparece como não encontrada.
O script é idempotente. O que comprova o encerramento é o inventário residual
vazio em todas as categorias.
