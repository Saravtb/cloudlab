# ADR-003 — Observabilidade e comportamento diante de falhas

**Status:** aceito
**Data:** 13 de agosto de 2026, ampliado em 14 de agosto de 2026
**Versão afetada:** v1.0-baseline em diante

## Contexto

O workload roda no AWS Fargate, onde não há acesso ao sistema operacional
hospedeiro. Não é possível abrir uma sessão no host, inspecionar arquivos de
log em disco ou anexar um depurador ao processo. Toda a capacidade de
diagnóstico precisa vir daquilo que a aplicação emite.

Além disso, a partir da versão v1.1 a aplicação passou a depender do Amazon
RDS. Uma dependência externa introduz uma classe de falha nova: o serviço pode
estar em execução e mesmo assim ser incapaz de cumprir parte do contrato.

## Alternativas consideradas

**Logs em arquivo dentro do container.** Descartada de imediato: o
armazenamento da tarefa é efêmero e desaparece com ela, e não há como acessá-lo.

**Logs em texto livre na saída padrão.** Simples de produzir, mas difícil de
consultar. Uma linha como "evento recebido com id abc" exige interpretação por
expressão regular para qualquer análise agregada.

**Logs estruturados em JSON na saída padrão, coletados pelo driver `awslogs`.**
Cada linha é um objeto com campos nomeados. O CloudWatch Logs Insights consegue
consultar campos diretamente, sem interpretação textual.

**Rota de saúde passiva.** Um `/health` que apenas confirma que o processo
responde. Barato, mas informa pouco: um serviço sem banco responderia
"saudável" enquanto falha em todas as gravações.

**Rota de saúde com sonda ativa.** O `/health` verifica de fato a dependência
antes de responder. Custa uma consulta por chamada, mas reporta o estado real.

## Decisão

Adotar **logs estruturados em JSON na saída padrão**, coletados pelo driver
`awslogs` para o log group `/ecs/cloudlab`, com retenção de 7 dias.

Adotar **rota `/health` com sonda ativa**, que executa uma consulta trivial no
banco a cada chamada e reporta o estado real da dependência.

Adotar o princípio de que **a indisponibilidade do banco não derruba a
aplicação**: o processo permanece vivo, o `/health` passa a reportar estado
degradado com a causa, e as rotas de dados respondem 503 com mensagem
explícita.

## Justificativa

Cada evento recebido gera uma linha JSON com horário, nível, nome do serviço,
versão, identificador do evento, tipo, origem e confirmação de gravação. Isso
permite responder perguntas como "quantos eventos de determinado tipo foram
recebidos" sem interpretar texto.

A retenção de 7 dias é decisão de custo. O CloudWatch cobra por ingestão e por
armazenamento; a vida útil do projeto é de duas semanas e não há requisito de
auditoria histórica.

A sonda ativa foi adotada após uma descoberta empírica. A primeira
implementação verificava a conexão apenas na inicialização. Quando o banco foi
parado deliberadamente com a aplicação em execução, o painel continuou
exibindo estado saudável e, pior, as requisições ficaram penduradas
indefinidamente — a conexão TCP havia ficado meio-aberta e a aplicação
aguardava uma resposta que nunca viria.

A correção combinou quatro mecanismos: keepalives TCP para detectar conexões
mortas, `statement_timeout` para limitar a duração de qualquer consulta,
validação de conexão pelo pool antes de entregá-la, e a sonda ativa no
`/health` que reavalia o estado e dispara reconexão em segundo plano.

O princípio de não derrubar a aplicação vem de uma observação sobre
diagnóstico: uma tarefa que encerra por falha de dependência aparece no ECS
apenas como `STOPPED`, sem indicação clara da causa. Uma tarefa viva que
responde "degradado, não foi possível obter conexão" comunica o problema
diretamente a quem opera.

## Consequências

**Positivas.** O estado real do sistema é visível tanto pela API quanto pelo
frontend. A transição entre saudável e degradado é registrada em log, o que
produz rastro de incidente no CloudWatch. A recuperação é automática: quando o
banco volta, a aplicação reconecta sem intervenção e sem reinício do container.

**Custos assumidos.** Cada chamada a `/health` executa uma consulta no banco.
Com o volume deste projeto o impacto é irrelevante, mas em um serviço de alto
tráfego seria necessário armazenar o resultado em cache por alguns segundos.

Quando o banco está indisponível, a resposta do `/health` leva cerca de cinco
segundos — o tempo limite de obtenção de conexão do pool. É um comportamento
aceitável e previsível, mas não instantâneo.

**Limitações reconhecidas.** Não foram configurados dashboards nem alarmes do
CloudWatch. Métricas de negócio, como taxa de eventos por minuto, não são
publicadas; seria possível derivá-las por consulta no Logs Insights, mas não
há painel pronto. Em uma evolução, um alarme sobre a ocorrência da mensagem
"banco deixou de responder" seria o primeiro item a implementar.

## Verificação

O comportamento foi validado empiricamente parando a instância RDS com a
aplicação em execução. Evidências `21-degradado-painel`,
`22-degradado-cloudwatch`, `23-recuperado-painel` e `24-rds-reiniciado` em
`/evidence`, que registram o incidente completo, da queda às 13:11 à
recuperação automática às 13:22.
