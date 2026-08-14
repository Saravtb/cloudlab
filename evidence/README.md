# Evidências operacionais — Projeto 1 AWS CloudLab

Este diretório reúne as evidências das duas versões implantadas do workload,
organizadas por versão. Cada subdiretório tem o próprio inventário explicando
o que cada arquivo comprova.

| Versão | Conteúdo | Tag |
| --- | --- | --- |
| `v1.0/` | Baseline mínimo: workload sem persistência no ECS com Fargate, observabilidade no CloudWatch e remoção completa dos recursos. | `v1.0-baseline` |
| `v1.1/` | Incremento: persistência no Amazon RDS, frontend próprio, credenciais no Secrets Manager e teste de resiliência com falha da dependência. | `v1.2` |

Ambas as versões foram implantadas pelos mesmos scripts versionados em
`/infra`, executados no AWS CloudShell, e removidas ao final por
`infra/cleanup.sh`.

Nenhum arquivo deste diretório contém credenciais, tokens ou identificadores
de conta. Os valores sensíveis foram substituídos por marcadores explícitos.
