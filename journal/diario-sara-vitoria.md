# Diário técnico — Sara Vitória

**Unidade curricular:** Pentesting em Nuvem
**Projeto:** Projeto 1 — AWS CloudLab
**Datas:** 13 e 14 de agosto de 2026

---

## Dia 1 — 13 de agosto

### Entrada 1 — Montei a aplicação e coloquei dentro de um container

**O que eu fiz.** Escrevi um serviço em Python com FastAPI que tem três
endereços: um que mostra o nome e a versão do serviço, um que responde se ele
está funcionando, e um que recebe um evento e devolve um identificador. Depois
escrevi um Dockerfile para empacotar tudo isso numa imagem.

**O que eu esperava.** Que a imagem funcionasse e que o programa rodasse sem
privilégio de administrador.

**O que aconteceu.** A imagem ficou com 158 MB e as três rotas responderam
certo. Rodei o comando `docker run --rm cloudlab-events:v1 id` e apareceu
`uid=10001`, que é o usuário comum que eu configurei — não apareceu `uid=0`,
que seria o root.

**Evidência.** `evidence/v1.0/01-imagem-local-e-nao-root.png`

**O que eu aprendi.** Entendi a diferença entre imagem e container. A imagem é
como uma receita pronta: um pacote parado, com o programa e tudo que ele
precisa para rodar. O container é o que nasce quando eu executo essa imagem —
é um processo em execução. Da mesma imagem eu posso criar vários containers.

Também entendi por que a linha `USER 10001:10001` no Dockerfile importa. Por
padrão, o container roda como root. Se alguém conseguisse invadir a aplicação,
já entraria com poder de administrador ali dentro. Colocando um usuário comum,
a aplicação faz só o que precisa: ler o código e responder na porta 8000. Ela
não precisa de mais nada, então não recebe mais nada.

**Custo.** Zero, porque foi tudo construído no CloudShell.

---

### Entrada 2 — Publiquei a imagem e rodei na AWS

**O que eu fiz.** Criei um repositório privado no Amazon ECR, mandei a imagem
para lá, criei uma task definition e executei o container no ECS com Fargate.

**O que eu esperava.** Que a aplicação ficasse disponível num endereço público
e respondesse pelas mesmas rotas que respondia na minha máquina.

**O que aconteceu.** A tarefa ficou com status RUNNING, usando 0.25 vCPU e
0.5 GiB. Acessei pelo IP público e os três endereços responderam. A imagem
ficou registrada com o digest `sha256:9c7b28…`.

**Evidência.** `evidence/v1.0/03-ecr-digest-cli.png`,
`evidence/v1.0/08b-ecs-task-fargate.png`

**O que eu aprendi.** Aprendi a diferença entre tag e digest. A tag é um apelido
que eu escolho, tipo `v1` — ela é prática, mas pode ser trocada. O digest é um
código gerado a partir do conteúdo da imagem. Se o conteúdo é o mesmo, o digest
é o mesmo. Isso ficou muito claro depois, quando publiquei duas tags diferentes
(`v3` e `v4`) e as duas tinham exatamente o mesmo digest, porque eu só tinha
mudado uma configuração fora da imagem.

Também entendi por que a task definition precisa do endereço completo do ECR e
não só do nome `cloudlab-events:v1`. Esse nome curto só existe no Docker da
máquina onde eu construí. O ECS está em outro lugar e precisa saber de qual
registro buscar.

E entendi o que é o Fargate: eu não tenho servidor nenhum para cuidar. Eu digo
quanta CPU e memória quero, e a AWS cuida da máquina por baixo. Pago só pelo
tempo em que a tarefa fica rodando.

**Recursos criados.** Repositório `cloudlab-events`, cluster `cloudlab-cluster`,
task definition `cloudlab-task`, security group `cloudlab-sg`.

**Custo.** Cerca de US$ 0,012 por hora com a tarefa em execução.

---

### Entrada 3 — Fiz os logs aparecerem no CloudWatch

**O que eu fiz.** Configurei o driver `awslogs` na task definition e fiz a
aplicação escrever cada evento como um JSON na saída padrão.

**O que eu esperava.** Ver os eventos aparecendo no CloudWatch.

**O que aconteceu.** Cada evento apareceu como um objeto JSON, com
identificador, tipo, origem e mensagem. Junto apareceram os logs de acesso do
servidor, que mostram de qual endereço veio cada requisição.

**Evidência.** `evidence/v1.0/06-cloudwatch-logs-cli.png`

**O que eu aprendi.** No Fargate eu não tenho acesso à máquina. Não posso entrar
nela e abrir um arquivo de log. Então tudo que eu quiser saber depois precisa
sair pela saída padrão da aplicação, porque é dali que o `awslogs` recolhe e
manda para o CloudWatch.

Por isso o formato do log faz diferença. Se eu escrevesse "evento recebido com
id abc", eu teria que ficar procurando texto depois. Escrevendo em JSON, com
campos separados, dá para fazer consultas de verdade — por exemplo, contar
quantos eventos de um determinado tipo chegaram.

Deixei a retenção em 7 dias porque o CloudWatch cobra por armazenamento e o
projeto dura duas semanas. Não faz sentido guardar mais que isso.

**Custo.** Muito baixo, quase nada no volume que a gente usou.

---

### Entrada 4 — Apaguei tudo e montei de novo

**O que eu fiz.** Rodei o script de limpeza no fim do dia e reconstruí o
ambiente do zero no dia seguinte.

**O que eu esperava.** Que os scripts conseguissem recriar tudo sem eu precisar
lembrar de nada.

**O que aconteceu.** Funcionou. O inventário residual depois da limpeza voltou
vazio, sem cluster, sem repositório, sem nada sobrando.

**Evidência.** `evidence/v1.1/25-cleanup.txt`

**O que eu aprendi.** Entendi por que o enunciado insiste que print de tela não
substitui o procedimento. Print mostra que funcionou uma vez. Script mostra
como fazer de novo — e qualquer pessoa do grupo consegue executar, mesmo sem
ter estado no teclado.

Também entendi por que a limpeza importa tanto nesse laboratório. O orçamento é
fixo, e se estourar a conta é desativada e a gente perde tudo. Além disso, o
saldo só atualiza a cada 8 ou 12 horas, então não daria tempo de reagir se algo
ficasse ligado sem eu perceber.

**Custo.** A limpeza é justamente o que evita custo.

---

## Dia 2 — 14 de agosto

### Entrada 5 — Mudamos de ideia sobre guardar os dados

**O que eu fiz.** No primeiro dia decidimos não guardar os eventos em lugar
nenhum: a aplicação recebia, registrava no log e pronto. No segundo dia, com o
professor pedindo uma interface, mudamos e colocamos um banco PostgreSQL no
Amazon RDS.

**O que eu esperava.** Que o banco subisse e que a aplicação conseguisse gravar.

**O que aconteceu.** A instância ficou disponível, a aplicação conectou na
primeira tentativa e criou a tabela sozinha. Os eventos passaram a continuar lá
mesmo depois de reiniciar a aplicação.

**Evidência.** `evidence/v1.1/12-persistencia.mp4`,
`evidence/v1.1/18-rds-configuracao.png`

**O que eu aprendi.** Aprendi que decisão de arquitetura depende do que o
sistema precisa fazer, não do que é mais bonito. Não guardar os dados era uma
decisão certa enquanto a aplicação só recebia eventos — era mais simples, mais
barata e atendia o que era pedido.

O que mudou foi o requisito. Uma tela que só envia evento e não mostra os
anteriores não serve para nada. E para mostrar os anteriores é preciso ter
guardado em algum lugar. Aí a mesma decisão que era certa passou a ser
insuficiente.

Escolhemos RDS e não DynamoDB porque o que a tela precisa é uma lista ordenada
por horário. Em SQL isso é uma linha de comando. No DynamoDB daria mais
trabalho de modelagem para o mesmo resultado.

**Recursos criados.** Instância `cloudlab-db` e o subnet group dela.

**Custo.** Cerca de US$ 0,018 por hora, mais o armazenamento enquanto existir.
É o recurso mais caro do projeto inteiro.

---

### Entrada 6 — Protegi o banco por grupo, não por endereço

**O que eu fiz.** Criei um security group só para o banco, liberando a porta
5432 apenas para quem pertence ao security group da aplicação. Não liberei
nenhum endereço IP. E criei o banco sem acesso público.

**O que eu esperava.** Que só a aplicação conseguisse conversar com o banco.

**O que aconteceu.** Funcionou em todas as vezes que reimplantei, sem eu
precisar mexer na regra — mesmo com o IP da tarefa mudando toda vez.

**Evidência.** `evidence/v1.1/14-db-sg-origem-security-group.png`

**O que eu aprendi.** Essa foi a parte que eu achei mais interessante. Security
group é um firewall que fica na interface de rede do recurso. Normalmente a
gente libera endereços IP, mas dá para liberar um outro security group inteiro
como origem.

Na prática isso significa que a pergunta que o banco faz não é "de qual
endereço você está vindo?", e sim "você pertence ao grupo autorizado?". Ter o
endereço certo não adianta nada. Só passa quem faz parte do grupo da aplicação.

E isso resolveu um problema real: o IP da minha tarefa muda toda vez que eu
implanto. Se a regra fosse por endereço, eu teria que corrigir a cada deploy.
Como é por grupo, continua funcionando sozinho.

O banco também não tem IP público, então nem existe caminho para alguém tentar
de fora da VPC.

**Custo.** Zero. Security group não é cobrado.

---

### Entrada 7 — Guardei a senha do banco sem colocar ela no código

**O que eu fiz.** O script gera uma senha aleatória, guarda no AWS Secrets
Manager, e a task definition guarda só o endereço do segredo — não a senha.

**O que eu esperava.** Que a senha não aparecesse em nenhum arquivo do projeto.

**O que aconteceu.** Na task definition aparece só
`arn:aws:secretsmanager:...`. A senha não está no repositório, nem na imagem,
nem no console.

**Evidência.** `evidence/v1.1/17-secrets-task-definition.png`

**O que eu aprendi.** Aqui a diferença entre execution role e task role deixou
de ser teoria para mim.

A **execution role** trabalha antes do container existir. É ela que baixa a
imagem do ECR e que busca a senha no Secrets Manager para entregar ao container
no momento em que ele começa a subir.

A **task role** é a identidade da aplicação depois que ela já está rodando.
Serviria se a minha aplicação precisasse chamar algum serviço da AWS por conta
própria. No nosso caso ela não chama — a conexão com o banco é uma conexão de
rede normal, com usuário e senha, não uma chamada de API da AWS.

Também aprendi uma limitação do laboratório. Existe uma forma melhor ainda, que
é o banco aceitar autenticação por IAM, sem senha nenhuma. Mas para isso eu
precisaria criar uma policy própria, e o Learner Lab não deixa criar policies
nem roles. Então usei a melhor opção possível dentro do que o ambiente permite,
e registrei no ADR-006 qual seria a opção ideal.

**Custo.** Cerca de US$ 0,40 por mês enquanto o segredo existir.

---

### Entrada 8 — Derrubei o banco de propósito para ver o que acontecia

**O que eu fiz.** Com a aplicação rodando normalmente, parei a instância do RDS
pelo console para ver como o sistema reagia.

**O que eu esperava.** Que a tela mostrasse que o banco estava fora do ar.

**O que aconteceu na primeira vez.** Deu errado. A tela continuou dizendo
"saudável" e, pior, quando tentei enviar um evento, a página simplesmente
travou. Ficou esperando para sempre.

**Por que travou.** Descobri que a conexão com o banco tinha ficado
meio-aberta. Do lado da aplicação a conexão parecia existir, mas do outro lado
não tinha mais ninguém. A aplicação mandava a pergunta e ficava esperando uma
resposta que nunca ia chegar, porque não havia nenhum tempo limite configurado.

**O que eu fiz para corrigir.** Coloquei quatro coisas: keepalives, que fazem o
sistema perceber quando a conexão morreu; um tempo limite para qualquer
consulta; uma verificação da conexão antes de usá-la; e uma checagem de verdade
no `/health`, que testa o banco a cada consulta em vez de confiar no que foi
verificado lá no início.

**O que aconteceu depois da correção.** Às 13:11 a tela mudou para "degradado"
em cerca de 5 segundos, mostrando o motivo. Tentar enviar um evento passou a
dar erro na hora, com mensagem clara. A página continuou abrindo normalmente.
Às 13:22, quando religuei o banco, a aplicação voltou sozinha para "saudável" —
sem eu reiniciar nada.

**Evidência.** `evidence/v1.1/21-degradado-painel.png`,
`22-degradado-cloudwatch.png`, `23-recuperado-painel.png`

**O que eu aprendi.** Aprendi que um health check que só verifica na
inicialização não serve para muita coisa. Ele responde sobre um momento que já
passou. Se o banco cair depois, ele continua dizendo que está tudo bem — e
quem está operando é enganado justamente na hora em que mais precisa de
informação correta.

E aprendi por que é melhor a aplicação continuar viva dizendo "estou
degradado" do que simplesmente morrer. Se ela morre, no console do ECS aparece
só `STOPPED`, e eu tenho que ir caçar o motivo. Se ela fica viva e diz "não
consegui conexão com o banco", o problema já está apontado.

Essa foi a parte do projeto que eu mais gostei, porque o erro apareceu por
causa de um teste que a gente fez de propósito. Se não tivéssemos testado, o
problema só ia aparecer na hora da apresentação.

**Custo.** Zero.

---

## O que eu levo desse projeto

O que mais me marcou foi perceber que arquitetura não é escolher o serviço mais
completo, e sim escolher o que é proporcional ao problema. A gente quase colocou
banco de dados no primeiro dia sem precisar, e teria gastado tempo e orçamento à
toa. Quando o banco passou a fazer sentido, aí sim entrou — e com motivo escrito.

Também aprendi que testar falha vale mais do que testar sucesso. O sistema
funcionando a gente já tinha visto várias vezes. Foi quando derrubamos o banco
de propósito que apareceu um problema de verdade, e deu tempo de corrigir.

E aprendi que documentar enquanto faz é muito mais fácil do que reconstruir
depois de memória. Os prints que eu tirei durante a operação viraram as
evidências da entrega, e vários deles não teriam como ser refeitos, porque os
recursos já não existem mais.



