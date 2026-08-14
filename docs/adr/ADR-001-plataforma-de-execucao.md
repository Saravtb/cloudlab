# ADR-001 — Plataforma de execução do workload

**Status:** aceito
**Data:** 13 de agosto de 2026
**Versão afetada:** v1.0-baseline em diante

## Contexto

O workload é um serviço HTTP mínimo que expõe três rotas (`GET /`, `GET /health`
e `POST /events`) e produz logs estruturados na saída padrão. A carga é
irregular e baixa: durante o projeto, o serviço recebe apenas requisições de
validação manual e do frontend, sem tráfego contínuo.

O ambiente é uma conta sandbox do AWS Academy Learner Lab, com orçamento
limitado, permissões restritas de IAM e sessões que encerram automaticamente.
A equipe não administra servidores nem tem acesso a recursos de rede
avançados.

O enunciado exige que o workload seja containerizado e publicado em registry,
o que já restringe parte do espaço de decisão, mas a plataforma de execução
do container permanece em aberto.

## Alternativas consideradas

**Amazon EC2.** Máquina virtual com Docker instalado. Dá controle total sobre
o sistema operacional e permite executar qualquer runtime. Em contrapartida,
a equipe passa a ser responsável por patching, hardening, monitoramento do
host e ciclo de vida da instância. O Learner Lab ainda para instâncias ao fim
da sessão e as reinicia na sessão seguinte, o que gera consumo de orçamento
não intencional. Para um serviço com três rotas, o esforço operacional é
desproporcional.

**AWS Lambda.** Execução sob demanda, sem servidor e sem custo ocioso. É a
opção mais econômica para carga irregular. Porém o enunciado exige entrega em
container publicado em registry e demonstração de task definition e runtime de
containers; embora o Lambda suporte imagens de container, o modelo de execução
por invocação não permite demonstrar os conceitos de cluster, task definition
e task exigidos. O Learner Lab também limita a 10 execuções concorrentes.

**Amazon ECS com AWS Fargate.** Executa containers sem provisionar ou
administrar servidores. A AWS gerencia o host, o patching e o isolamento; a
equipe declara CPU, memória, rede e imagem em uma task definition. A cobrança
é por vCPU e memória alocadas durante a execução da tarefa. Permite demonstrar
diretamente cluster, task definition, task, security group e integração com o
CloudWatch.

## Decisão

Adotar **Amazon ECS com AWS Fargate**, executando uma tarefa autônoma
(*standalone task*) no menor dimensionamento disponível: 0.25 vCPU e 0.5 GiB
de memória, plataforma 1.4.0, arquitetura X86_64, modo de rede `awsvpc`.

## Justificativa

A responsabilidade operacional é proporcional ao problema. O workload não
precisa de acesso ao sistema operacional, não instala pacotes em tempo de
execução e não mantém estado local. Tudo o que ele exige é um runtime de
container com rede e saída padrão — exatamente o que o Fargate entrega sem
exigir administração de host.

A decisão também é a que melhor atende aos critérios de avaliação: o projeto
pontua explicitamente containerização, ECR e execução no ECS com Fargate.
Escolher EC2 significaria assumir trabalho operacional que não gera nota, e
escolher Lambda impediria demonstrar os artefatos exigidos.

O dimensionamento mínimo é adequado porque o serviço é I/O-bound e sem
concorrência relevante. Durante os testes, a tarefa respondeu a todas as
requisições sem degradação perceptível com 0.25 vCPU.

Optou-se por tarefa autônoma em vez de ECS Service porque não há requisito de
disponibilidade contínua nem de auto-recuperação; o serviço é iniciado para
demonstração e removido em seguida. Um Service manteria a tarefa
permanentemente em execução, consumindo orçamento sem benefício acadêmico.

## Consequências

**Positivas.** Nenhum servidor para administrar. Implantação declarativa e
reproduzível por script. Cobrança apenas durante a execução da tarefa.
Integração direta com CloudWatch Logs pelo driver `awslogs` e com o Secrets
Manager pelo campo `secrets` da task definition.

**Negativas e limitações aceitas.** A tarefa autônoma não é reiniciada
automaticamente se falhar — não há auto-recuperação, e a queda da tarefa
exigiria nova execução manual. O endereço IP público muda a cada execução, o
que obriga a atualizar a regra do security group e impede um endereço estável.
Um Application Load Balancer resolveria ambos, mas está fora do escopo desta
etapa.

O Fargate também não permite acesso ao host, o que elimina algumas
possibilidades de diagnóstico; em contrapartida, força o uso de logs
estruturados, que é a prática desejada.

## Verificação

Evidências `03-task-running-cli`, `08a-ecs-task-lista`, `08b-ecs-task-fargate`
e `15-task-definition-container` em `/evidence`, demonstrando tarefa em estado
RUNNING, launch type FARGATE, dimensionamento e imagem resolvida a partir do
ECR.
