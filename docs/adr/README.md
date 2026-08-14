# Registros de decisão arquitetural

Cada documento segue a estrutura exigida pelo enunciado: contexto,
alternativas consideradas, decisão, justificativa e consequências.

| Documento | Decisão registrada |
| --- | --- |
| [ADR-001](ADR-001-plataforma-de-execucao.md) | Amazon ECS com AWS Fargate como plataforma de execução |
| [ADR-002](ADR-002-estrategia-de-dados.md) | Amazon RDS PostgreSQL, substituindo a decisão inicial de não persistir |
| [ADR-003](ADR-003-observabilidade.md) | Logs estruturados no CloudWatch e health check com sonda ativa |
| [ADR-004](ADR-004-automacao-e-reprodutibilidade.md) | Scripts AWS CLI versionados em vez de CloudFormation |
| [ADR-005](ADR-005-custos-e-dimensionamento.md) | Dimensionamento mínimo e remoção ao final de cada sessão |
| [ADR-006](ADR-006-credenciais-e-controle-de-acesso.md) | Secrets Manager e segmentação de rede por security group |

## Decisões que mudaram durante o projeto

O ADR-002 registra uma reversão. A decisão inicial foi não persistir, e ela
foi implantada e validada na versão `v1.0-baseline`. A mudança de contexto —
o interesse em uma interface de usuário e a redução da pressão de prazo —
tornou a persistência necessária e viável. As duas decisões e o motivo da
troca estão documentados.

O ADR-003 registra uma correção decorrente de teste. A primeira implementação
do health check verificava a conexão apenas na inicialização, e um teste
deliberado de parada do banco revelou que a aplicação ficava pendurada em vez
de reportar o problema. A correção está descrita e foi verificada
empiricamente.

## Restrições do ambiente que condicionaram decisões

O AWS Academy Learner Lab não permite criar usuários, grupos, roles ou
policies de IAM. Isso impediu a adoção da autenticação do RDS por IAM, que
seria tecnicamente superior à senha em segredo. O ADR-006 documenta a opção
pretendida, a razão da inviabilidade e a alternativa adotada.

O Enhanced Monitoring do RDS não é suportado pelo ambiente, o que está
registrado no ADR-002.
