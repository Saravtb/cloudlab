# Matriz de alternativas

Comparação das opções avaliadas antes de fixar a arquitetura. As decisões
correspondentes estão registradas em `/docs/adr`.

## Critérios

| Critério | O que mede |
| --- | --- |
| Esforço operacional | Quanto a equipe precisa administrar por conta própria |
| Custo no ambiente | Impacto sobre o orçamento fixo do Learner Lab |
| Aderência ao enunciado | Quanto permite demonstrar os artefatos exigidos |
| Viabilidade no lab | Se as permissões do ambiente permitem |
| Adequação ao workload | Se atende ao padrão de uso real do serviço |

## Alternativas de computação

| | Amazon EC2 | AWS Lambda | ECS + Fargate |
| --- | --- | --- | --- |
| Esforço operacional | Alto: patching, hardening e ciclo de vida do host | Baixo | Baixo: sem servidor a administrar |
| Custo no ambiente | Alto: o lab reinicia instâncias paradas na sessão seguinte | Muito baixo: cobrança por invocação | Baixo: cobrança durante a execução |
| Aderência ao enunciado | Parcial: não exercita task definition | Parcial: não exercita cluster nem task | Completa: cluster, task definition, task |
| Viabilidade no lab | Sim, com limite de 9 instâncias | Sim, com 10 execuções concorrentes | Sim |
| Adequação ao workload | Excessivo para três rotas | Adequado à carga, inadequado à entrega | Adequado |

**Selecionado: Amazon ECS com AWS Fargate.** Ver ADR-001.

O Lambda seria a opção mais econômica para a carga real, que é irregular e
baixa. Foi descartado por não permitir demonstrar os artefatos de container
exigidos pelo enunciado, não por inadequação técnica.

## Alternativas de dados

| | Sem persistência | DynamoDB | S3 | EFS | RDS PostgreSQL |
| --- | --- | --- | --- | --- | --- |
| Esforço operacional | Nenhum | Baixo | Baixo | Médio | Médio: rede, credencial, instância |
| Custo no ambiente | Zero | Muito baixo, sob demanda | Muito baixo | Baixo | O mais alto do projeto |
| Leitura ordenada | Não suporta | Exige índice ou chave de ordenação | Inadequado | Não estruturado | Nativo |
| Modelo de consulta | — | Chave-valor | Objeto | Arquivo | Relacional |
| Viabilidade no lab | Sim | Sim | Sim | Sim | Sim |
| Adequação ao requisito | Suficiente até a v1.0 | Suficiente, com modelagem extra | Insuficiente | Insuficiente | Adequado |

**Selecionado inicialmente: sem persistência.** Implantado e validado na
`v1.0-baseline`.

**Selecionado na revisão: Amazon RDS PostgreSQL.** Ver ADR-002.

A mudança decorreu da inclusão de um frontend que lista os eventos anteriores,
o que exige leitura de estado. Entre RDS e DynamoDB, a escolha pendeu para o
relacional porque o padrão de acesso é uma listagem ordenada por horário —
trivial em SQL e que no DynamoDB exigiria modelagem adicional.

## Alternativas de automação

| | Console web | CloudFormation | Scripts AWS CLI |
| --- | --- | --- | --- |
| Reprodutibilidade | Nenhuma | Alta | Alta |
| Remoção de recursos | Manual | Automática pela stack | Script próprio |
| Custo de depuração | Baixo | Alto: rollback recomeça do zero | Baixo: incremental |
| Valor pedagógico | Baixo | Médio: esconde a ordem das chamadas | Alto: ordem explícita |
| Aceito pelo enunciado | Não como entrega | Sim | Sim |

**Selecionado: scripts AWS CLI versionados.** Ver ADR-004.

## Alternativas de credenciais

| | Variável de ambiente | Arquivo na imagem | Secrets Manager | Autenticação por IAM |
| --- | --- | --- | --- | --- |
| Exposição da senha | Visível no console | Persiste na imagem | Apenas o ARN é referenciado | Não existe senha |
| Rotação | Exige nova revisão | Exige nova imagem | Possível sem alterar código | Não aplicável |
| Custo | Zero | Zero | Cerca de US$ 0,40 por mês | Zero |
| Viabilidade no lab | Sim | Sim | Sim | **Não**: exige criar policy |

**Selecionado: AWS Secrets Manager.** Ver ADR-006.

A autenticação do RDS por IAM é tecnicamente superior, pois elimina a senha.
Não foi adotada porque o Learner Lab não permite criar roles nem policies, e
usar a `LabRole` — de permissões amplas — não representaria menor privilégio.
