# ADR-004 — Automação da implantação e reprodutibilidade

**Status:** aceito
**Data:** 13 de agosto de 2026
**Versão afetada:** v1.0-baseline em diante

## Contexto

O critério de aceite exige que a implantação possa ser repetida em ambiente
limpo e que outro grupo consiga compreender e recriar a solução sem depender
da memória dos autores. O enunciado permite AWS CloudFormation ou scripts AWS
CLI versionados, e afirma explicitamente que uma sequência de capturas de tela
não substitui a demonstração.

Há uma restrição adicional relevante: apenas um integrante da equipe tem acesso
efetivo ao ambiente AWS. Isso significa que o conhecimento operacional não pode
residir em quem operou o teclado — ele precisa estar no repositório.

## Alternativas consideradas

**Console web, documentado por capturas de tela.** Rápido para explorar e
aprender. Não é reproduzível: o console muda, os passos se perdem e a
sequência de cliques não pode ser executada por outra pessoa. O próprio
enunciado desqualifica essa abordagem como entrega.

**AWS CloudFormation.** Infraestrutura declarativa, com criação e remoção
gerenciadas pela AWS por meio de stacks. É a opção mais elegante: excluir a
stack remove tudo o que ela criou, o que praticamente elimina o risco de
recursos órfãos consumindo orçamento.

Foi descartada por duas razões. A primeira é o custo de depuração: um erro em
template frequentemente provoca rollback completo, e cada ciclo de correção
recomeça do zero, o que era incompatível com o prazo no momento da decisão. A
segunda é pedagógica: o template esconde a sequência de chamadas de API, e a
equipe precisava compreender a ordem real das operações — criar o repositório,
autenticar, publicar a imagem, registrar a task definition, criar o cluster,
configurar a rede e executar a tarefa.

**Scripts AWS CLI versionados.** Cada comando é explícito e legível. A ordem
das operações fica evidente. A depuração é incremental: um passo que falha não
desfaz os anteriores. Em contrapartida, a remoção não é automática — é preciso
escrever e manter o script de limpeza correspondente.

## Decisão

Adotar **scripts AWS CLI versionados no repositório**, em `/infra`, executados
no AWS CloudShell.

Três scripts, com responsabilidades separadas:

`01-create-rds.sh` cria a camada de dados — security group da aplicação,
security group do banco, subnet group, segredo no Secrets Manager e a instância
PostgreSQL.

`deploy.sh` publica e executa o workload — repositório ECR, construção e envio
da imagem, log group, task definition, cluster, rede e execução da tarefa.

`cleanup.sh` remove tudo o que os dois anteriores criaram, na ordem correta de
dependência, e imprime o inventário residual ao final.

## Princípios adotados nos scripts

**Idempotência.** Cada script verifica a existência do recurso antes de criá-lo
e reaproveita o que já existe. Executar duas vezes não gera erro nem duplicação.
O `cleanup.sh` tolera a ausência de qualquer recurso e prossegue.

**Falha explícita.** Os scripts de criação usam `set -euo pipefail` e
interrompem no primeiro erro. Quando a tarefa não alcança o estado RUNNING, o
`deploy.sh` consulta e imprime o motivo informado pelo ECS, em vez de deixar o
operador procurar no console.

**Descoberta em vez de valores fixos.** Identificadores de conta, VPC, subnets,
security groups e ARNs são consultados em tempo de execução. Nenhum
identificador do ambiente está escrito no código, o que permite executar os
mesmos scripts em outra conta sem edição.

**Verificação embutida.** O `deploy.sh` executa `docker run --rm ... id` antes
de publicar a imagem, comprovando que o processo não roda como root. A
verificação é parte da implantação, não um passo manual que pode ser esquecido.

**Remoção que exclui, não que pausa.** O `cleanup.sh` exclui a instância RDS em
vez de pará-la, porque o Learner Lab pode não pará-la ao encerrar a sessão e a
AWS reinicia instâncias paradas após sete dias.

## Justificativa

A decisão privilegia compreensão e recuperação de erro sobre elegância. Ao
longo do projeto, os scripts foram executados repetidamente, em sessões
distintas e após remoções completas — e a reprodutibilidade foi demonstrada na
prática, não apenas afirmada.

O versionamento no Git resolve simultaneamente três problemas: distribui o
conhecimento operacional para todos os integrantes, permite que a contribuição
individual seja rastreável por autoria de commit, e garante que a sequência de
comandos sobreviva ao encerramento da sessão do laboratório.

## Consequências

**Positivas.** Qualquer integrante pode conduzir a implantação lendo os
scripts, mesmo sem ter operado o teclado. A implantação inteira, do código à
tarefa em execução, leva cerca de dois minutos. A ordem de dependência entre os
recursos está codificada e documentada.

**Negativas.** A remoção depende de um script mantido manualmente: um recurso
novo criado sem a atualização correspondente no `cleanup.sh` se tornaria órfão.
O CloudFormation não teria esse risco.

Não há controle de estado. Os scripts não sabem o que já existe além do que
consultam, e não detectam divergência entre o declarado e o implantado.

**Achado operacional registrado.** O endereço IP de saída do AWS CloudShell
muda entre sessões. Como o security group autoriza origens `/32`, o acesso a
partir do CloudShell exige reautorização quando a sessão é reiniciada, mesmo
com a tarefa saudável. Esse comportamento foi observado durante a operação e
está registrado no runbook.

**Evolução prevista.** Traduzir os scripts para um template CloudFormation é o
próximo passo natural. A ordem de dependência já está compreendida e
documentada, o que torna a tradução um exercício mecânico em vez de
exploratório.

## Verificação

Repositório `/infra` com os três scripts. A implantação foi executada com
sucesso em ambiente limpo após remoção completa, em duas versões distintas do
workload. Termo de remoção em `evidence/v1.1/25-cleanup.txt`, com inventário
residual vazio.
