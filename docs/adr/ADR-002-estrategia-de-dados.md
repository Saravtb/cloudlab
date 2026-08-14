# ADR-002 — Estratégia de dados e persistência

**Status:** aceito, substitui decisão anterior de não persistir
**Data:** 13 de agosto de 2026 (decisão inicial), revista em 14 de agosto de 2026
**Versão afetada:** v1.1 em diante

## Contexto

O contrato funcional mínimo exige que `POST /events` receba um evento sintético
e responda com um identificador e o estado do processamento. O enunciado é
explícito ao afirmar que persistência não é obrigatória e que a equipe pode
manter o processamento sem estado, desde que justifique a decisão e demonstre
que o benefício compensa a complexidade, o custo e o esforço operacional
adicionais.

Este registro documenta duas decisões sucessivas, porque a segunda substitui a
primeira e as razões da mudança fazem parte do raciocínio arquitetural.

## Alternativas consideradas

**Sem persistência.** O evento é validado, registrado em log estruturado e
descartado. Não há banco, credenciais, rede interna nem custo de
armazenamento. É a opção mais simples e a mais barata.

**Amazon DynamoDB.** Banco NoSQL gerenciado, cobrança sob demanda, sem
instância para administrar. Adequado a gravações de alto volume com chave
simples. Exigiria uma task role com permissão de escrita na tabela.

**Amazon S3.** Cada evento gravado como objeto. Barato e durável, mas
inadequado para leitura ordenada e consulta dos eventos recentes, que é o
padrão de acesso do frontend.

**Amazon EBS ou Amazon EFS.** Volumes de bloco ou de arquivos. O EBS não é
compatível com o modelo de tarefa efêmera do Fargate, e o EFS resolveria a
persistência de arquivos sem oferecer consulta estruturada.

**Amazon RDS PostgreSQL.** Banco relacional gerenciado. Oferece consulta
ordenada, tipos de dados adequados, transações e um modelo familiar. Custa
mais que as demais opções e introduz rede interna, credenciais e um recurso
que permanece cobrado enquanto existir.

## Decisão inicial e sua revisão

**Decisão de 13 de agosto: não persistir.** Com prazo curto e nenhum
requisito de leitura, o processamento sem estado atendia integralmente o
contrato mínimo. O evento era registrado em log estruturado no CloudWatch, o
que já oferece rastreabilidade sem custo adicional de armazenamento
gerenciado. A decisão foi implantada e validada na versão `v1.0-baseline`.

**Revisão de 14 de agosto: adotar Amazon RDS PostgreSQL.** Dois fatos
alteraram o contexto. Primeiro, o docente manifestou interesse em uma
interface de usuário, e um frontend que apenas envia eventos sem exibir os
anteriores tem pouco valor demonstrativo — a listagem exige leitura de estado,
o que é impossível sem persistência. Segundo, o prazo deixou de ser
restritivo, o que tornou viável assumir a complexidade adicional.

A escolha entre RDS e DynamoDB pendeu para o RDS porque o padrão de acesso do
frontend é uma listagem ordenada por horário de recebimento, que é uma
consulta relacional trivial e que no DynamoDB exigiria modelagem de chave de
ordenação ou um índice secundário. O ganho de simplicidade conceitual superou
a diferença de custo, que em ambos os casos é baixa na escala do projeto.

## Configuração adotada

Instância `cloudlab-db`, PostgreSQL 16.14, classe `db.t3.micro`, 20 GiB de
armazenamento gp2, zona de disponibilidade única, sem acesso público, sem
retenção de backups automáticos e sem Enhanced Monitoring.

Esquema único, com a tabela `events` contendo identificador UUID, tipo,
origem, mensagem, estado e horário de recebimento. A tabela é criada pela
própria aplicação na inicialização, de forma idempotente.

## Justificativa

O RDS entrega exatamente o que o novo requisito pede — leitura ordenada dos
eventos recentes — sem que a equipe administre um servidor de banco. A classe
`db.t3.micro` é a menor disponível e é suficiente para uma tabela com dezenas
de registros e um único cliente.

As opções desabilitadas são decisões conscientes de custo, não omissões. A
zona única é aceitável porque não há requisito de disponibilidade. A retenção
de backups foi zerada porque os dados são sintéticos e descartáveis; em um
ambiente real isso seria inaceitável. O Enhanced Monitoring não é suportado
pelo Learner Lab.

A criptografia em repouso não foi habilitada. Os dados são sintéticos e
acadêmicos, sem qualquer requisito de confidencialidade, e habilitá-la
exigiria uma chave do KMS. Em um ambiente com dados reais essa decisão seria
diferente.

## Consequências

**Positivas.** O frontend passou a exibir os eventos gravados, o que torna a
demonstração muito mais convincente. A persistência foi verificada
empiricamente: eventos registrados antes de uma parada deliberada do banco
continuavam disponíveis após a recuperação.

**Negativas e riscos assumidos.** O banco é o recurso mais caro do projeto e é
cobrado enquanto existir, mesmo ocioso. O Learner Lab pode não pará-lo ao
encerrar a sessão, e a AWS reinicia automaticamente instâncias paradas após
sete dias. Por isso o procedimento de remoção exclui a instância em vez de
apenas pará-la.

A aplicação passou a ter uma dependência externa cuja indisponibilidade afeta
as rotas de dados. Esse risco foi tratado explicitamente e está documentado no
ADR-003.

**Coerência a manter.** O diagrama de arquitetura, o inventário de recursos e
a estimativa de custo devem refletir a presença do banco. Qualquer versão
anterior desses artefatos que descreva o workload como sem estado corresponde
à `v1.0-baseline`, não à versão final.

## Verificação

Evidências `12-persistencia.mp4`, `16-log-persisted-true`,
`18-rds-configuracao` e `20-frontend-eventos-persistidos` em `/evidence`.
