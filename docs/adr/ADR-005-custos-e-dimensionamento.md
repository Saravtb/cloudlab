# ADR-005 — Custos e dimensionamento

**Status:** aceito
**Data:** 13 de agosto de 2026, revisto em 14 de agosto de 2026
**Versão afetada:** v1.0-baseline e v1.1

## Contexto

A conta do AWS Academy Learner Lab tem orçamento limitado e fixo. O ambiente
avisa que exceder o orçamento desativa a conta e que todo o progresso e os
recursos são perdidos. O saldo é atualizado a cada 8 a 12 horas, ou seja, o
valor exibido não reflete a atividade mais recente — não é possível reagir a
um gasto inesperado em tempo real.

Isso muda a natureza da decisão de custo. Em um ambiente comercial, um gasto
excessivo produz uma fatura maior. Aqui, produz a perda de todo o trabalho.
Por isso o dimensionamento foi tratado como restrição de projeto, não como
otimização posterior.

## Alternativas de controle consideradas

**AWS Budgets com alarme.** O ambiente já monitora o orçamento, mas com a
mesma latência de 8 a 12 horas. Um alarme não chegaria a tempo de evitar o
estouro causado por um recurso esquecido durante a noite.

**Manter o ambiente permanentemente de pé.** Simplificaria a operação, já que
o endereço público não mudaria e não haveria reimplantação. Foi descartada: é
justamente o padrão que consome orçamento sem gerar valor, e o enunciado
menciona explicitamente que recursos mantidos continuamente sem necessidade
estão fora do escopo.

**Dimensionar para folga.** Escolher classes maiores para evitar problemas de
desempenho. Descartada por ausência de evidência de necessidade: o workload é
I/O-bound, com um único cliente e dezenas de registros.

**Dimensionamento mínimo com remoção ao fim de cada sessão.** Adotada.

## Decisão

Adotar o **menor dimensionamento disponível em cada serviço** e **remover todos
os recursos ao final de cada sessão de trabalho**, tratando a implantação como
operação repetível e barata em vez de ambiente permanente.

| Recurso | Dimensionamento | Decisão de custo |
| --- | --- | --- |
| AWS Fargate | 0.25 vCPU, 0.5 GiB | Menor combinação suportada |
| Amazon RDS | `db.t3.micro`, 20 GiB gp2, AZ única | Menor classe burstable; sem Multi-AZ |
| Backups do RDS | Retenção zero | Dados sintéticos e descartáveis |
| CloudWatch Logs | Retenção de 7 dias | Vida útil do projeto é de duas semanas |
| Amazon ECR | Uma imagem de cerca de 56 MB | Base `python:3.12-slim` em vez da completa |
| Secrets Manager | Um segredo | Estritamente o necessário |

## Estimativa de custo

Valores de referência para a região `us-east-1`, sob demanda. Os preços devem
ser confirmados na AWS Pricing Calculator antes de qualquer citação formal,
pois estão sujeitos a alteração.

**Custo por hora de ambiente completo em execução**

O Fargate cobra por vCPU-hora e por GB-hora alocados. Com 0.25 vCPU e 0.5 GiB,
o custo horário da tarefa fica na ordem de US$ 0,012. A instância
`db.t3.micro` de PostgreSQL fica na ordem de US$ 0,018 por hora. Somados, o
ambiente em operação custa aproximadamente **US$ 0,03 por hora**.

**Custos que independem do tempo de execução**

O armazenamento de 20 GiB gp2 é cobrado enquanto a instância existir, na ordem
de US$ 2,30 por mês. O segredo no Secrets Manager custa cerca de US$ 0,40 por
mês. A imagem no ECR, com 56 MB, representa menos de US$ 0,01 por mês. A
ingestão de logs no volume deste projeto é desprezível.

**Comparação que sustenta a decisão de remoção**

Mantido continuamente por 30 dias, o ambiente custaria aproximadamente US$ 22
a US$ 25. Executado apenas durante as sessões de trabalho — estimadas em cerca
de 8 horas ao longo do projeto — o custo de computação fica abaixo de US$ 0,30,
e os custos de armazenamento desaparecem junto com os recursos.

A diferença é de aproximadamente duas ordens de grandeza. É essa diferença que
justifica tratar a remoção como parte do procedimento operacional, e não como
tarefa opcional de encerramento.

## Justificativa das opções desabilitadas

Cada recurso desligado é decisão consciente, e todas seriam diferentes em um
ambiente de produção.

**Multi-AZ desabilitado.** Não há requisito de disponibilidade. Habilitá-lo
dobraria o custo da instância para proteger dados descartáveis.

**Backups automáticos com retenção zero.** Os dados são sintéticos e
recriáveis. Em produção, essa configuração seria inaceitável.

**Enhanced Monitoring desabilitado.** Não é suportado pelo Learner Lab, e as
métricas padrão do CloudWatch são suficientes na escala do projeto.

**Criptografia em repouso não habilitada.** Ausência de requisito de
confidencialidade em dados sintéticos. Habilitá-la exigiria uma chave do KMS,
com custo próprio.

**Tarefa autônoma em vez de ECS Service.** Um Service manteria a tarefa
permanentemente em execução e a reiniciaria automaticamente, o que é
desejável em produção e contraproducente aqui.

## Consequências

**Positivas.** O consumo de orçamento ficou restrito às horas de trabalho
efetivo. Nenhum recurso foi mantido de pé entre sessões. A remoção ao final de
cada sessão forçou a maturidade dos scripts de implantação, porque cada retomada
exigia uma reconstrução completa — o que na prática validou a reprodutibilidade
exigida pelo critério de aceite.

**Negativas.** O endereço IP público muda a cada implantação, o que exige
atualizar a regra do security group e impede um endereço estável para
demonstração. A retomada do trabalho tem um custo fixo de alguns minutos, mais
o tempo de provisionamento do RDS.

**Risco residual monitorado.** O maior risco financeiro do projeto é uma
instância RDS esquecida em execução. O ambiente pode não pará-la ao encerrar a
sessão, e a AWS reinicia instâncias paradas após sete dias. O `cleanup.sh`
trata isso excluindo a instância em vez de pará-la, e o inventário residual
impresso ao final permite conferir que nada permaneceu.

## Verificação

Evidências `08b-ecs-task-fargate` e `18-rds-configuracao` em `/evidence`,
comprovando o dimensionamento efetivamente implantado. Termo de remoção em
`evidence/v1.1/25-cleanup.txt`, com inventário residual vazio em todas as
categorias.
