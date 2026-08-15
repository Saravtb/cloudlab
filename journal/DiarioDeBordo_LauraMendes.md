# Diário de Bordo
### PROJETO 1 — AWS CLOUDLAB

**Preparado por:**
Laura Mendes Teixeira

---

## Etapa 1 - Estruturando o projeto em pastas

Criei a pasta raiz do projeto, Pay, e organizei ele em duas subpastas principais: backend e frontend. A ideia desde o início era separar claramente a lógica do servidor da interface do usuário.

Separar backend e frontend em pastas distintas facilita muito depois, cada parte pode ser desenvolvida, testada e (mais pra frente) containerizada de forma independente, sem uma bagunçar o código da outra.

<img width="485" alt="Captura de tela 2026-08-14 212601" src="https://github.com/user-attachments/assets/1778de8b-050a-4c69-a9f4-4ca13ce4d0fc" />


---

## Etapa 2 - Criando o backend do zero

No terminal, entrei na pasta com cd backend. De lá, criei o primeiro arquivo do projeto: o requirements.txt, direto pelo VS Code (botão direito na pasta backend - New File), e escrevi dentro dele a dependência fastapi[standard].

Entendi o papel do requirements.txt: é a lista de dependências Python do projeto, que depois o pip install -r requirements.txt lê para instalar tudo que o backend precisa pra rodar. Também entendi que fastapi[standard] já traz junto o Uvicorn (servidor) e outras dependências úteis, sem precisar instalar cada uma separadamente.

---

## Etapa 3 - Frontend do sistema

Criei a pasta frontend, com HTML, CSS e JavaScript, para dar uma interface visual ao sistema de pagamentos.

<img width="485" alt="Captura de tela 2026-08-14 203055" src="https://github.com/user-attachments/assets/70f2e14a-3a59-4b56-a9c7-a74daf26c4f0" />



---

## Etapa 4 - Conectando o banco de dados PostgreSQL

Configurei o PostgreSQL como banco de dados do backend, ainda rodando localmente na minha máquina, para guardar as informações do sistema de pagamentos.

---

## Etapa 5 - Publicando no GitHub

Depois que o sistema estava rodando localmente, criei o repositório no meu GitHub e publiquei o código do Pay lá.

Publicar cedo no GitHub, mesmo ainda em desenvolvimento local, ajuda a ter um histórico de versões e facilita compartilhar o código com o resto do grupo depois.

---

## Etapa 6 - Testando no VirtualBox com Docker

Todos os integrantes do grupo configuraram um container Docker dentro do VirtualBox, e rodei o Pay ali, num ambiente separado da minha máquina.

Testar num ambiente isolado (VirtualBox + Docker) mostra se o sistema realmente funciona por conta própria, sem depender de configurações que só existem na minha máquina pessoal, é um passo intermediário importante antes de confiar que ele vai funcionar na nuvem.

---

## Etapa 7 - Confrontando o sistema completo com os recursos da AWS

Ao testar os recursos que o grupo ia usar na AWS (ECS/Fargate, RDS), vi que o sistema completo do Pay, com frontend elaborado e várias funcionalidades de backend, era robusto demais para o escopo do projeto CloudLab.

A decisão de arquitetura depende do que o projeto realmente precisa entregar, não de quão completo o sistema é capaz de ser. O Pay tinha muito mais funcionalidade do que a disciplina de Pentesting em Nuvem pedia. Por isso, decidimos simplificar, cortando o frontend elaborado e parte do backend, para que o sistema se alinhasse aos recursos que seriam efetivamente usados na AWS, dando origem ao CloudLab.
