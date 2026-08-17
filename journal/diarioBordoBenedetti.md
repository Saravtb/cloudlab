Diário de Bordo — Projeto AWS CloudLab
05/08 — Inscrição na AWS Academy

Uma das primeiras coisas que aconteceram no projeto foi a inscrição da turma na AWS Academy, feita pelo professor. Logo em seguida, ficamos com acesso liberado à plataforma e aos cursos disponíveis nela, o que marcou o início oficial do nosso contato com o ambiente e os conteúdos formais da AWS.

06/08 — Kickoff do projeto

Com o acesso à AWS Academy já liberado, demos início oficial ao projeto em grupo. Discutimos o escopo geral do trabalho — uma aplicação containerizada rodando na infraestrutura da AWS — e dividimos as primeiras responsabilidades entre os integrantes. Nesse primeiro momento, o foco foi entender o que seria exigido pela disciplina e mapear quais tecnologias precisaríamos estudar do zero: Docker, containers e os serviços da AWS voltados para computação em nuvem.

07/08 — Primeiro contato com a AWS

Começamos a explorar o ambiente do AWS Academy Learner Lab, entendendo suas limitações específicas (permissões restritas de IAM, impossibilidade de criar roles customizadas, uso obrigatório da LabRole). Nesse dia, o grupo todo navegou pelo console da AWS para reconhecer a interface e identificar quais serviços estariam disponíveis para o projeto.

08/08 e 09/08 — Explorando os serviços da AWS

Dedicamos esses dias a estudar, em conjunto, os principais serviços que a AWS oferece para hospedar aplicações: EC2, ECS, Fargate, S3, RDS e DynamoDB. Discutimos as diferenças entre rodar uma aplicação em uma instância EC2 tradicional versus uma abordagem serverless, e entendemos por que o Fargate se encaixava melhor nas restrições do Learner Lab.

11/08 — Introdução ao Docker

Começamos o aprendizado prático de Docker como grupo: conceitos de imagem, container, Dockerfile e camadas (layers). Fizemos os primeiros testes de build e execução de containers localmente, entendendo a lógica de isolamento e portabilidade que o Docker oferece — base necessária para tudo que viria depois no projeto.

12/08 — Docker aplicado à nossa API

Demos continuidade ao aprendizado de Docker, agora aplicando os conceitos diretamente na construção da nossa API. Escrevemos o primeiro Dockerfile funcional da aplicação e testamos o container rodando localmente antes de pensar em subir para a nuvem.

13/08 — Início da definição da arquitetura

A partir desse ponto, fiquei responsável por conduzir a parte de arquitetura do projeto: selecionar quais serviços específicos da AWS seriam utilizados e desenhar como eles se conectariam entre si. Comecei mapeando o fluxo básico — Equipe, ECR, ECS/Fargate, banco de dados e logs — e justificando cada escolha frente às alternativas disponíveis.

14/08 — Primeira versão da arquitetura

Finalizei a primeira versão do desenho de arquitetura (v1), utilizando Amazon ECR para armazenar a imagem, ECS com Fargate para execução, DynamoDB para persistência de dados e CloudWatch para logs. Apresentei essa versão ao grupo para validação e discutimos possíveis melhorias, principalmente do ponto de vista de segurança.

15/08 — Evolução da arquitetura (v1.1)

Revisamos a primeira versão e decidimos evoluir a arquitetura: substituímos o DynamoDB por RDS PostgreSQL, já que os dados da aplicação possuem relações bem definidas entre si, e adicionamos camadas de segurança que ainda não existiam — Secrets Manager para gerenciar a senha do banco de forma segura, e dois Security Groups separados (um para a API, outro isolando o banco de dados). Essa versão ficou mais próxima de uma arquitetura de produção real.

16/08 — Automatizando o provisionamento

Com a arquitetura final definida, comecei a desenvolver um script responsável por automatizar a montagem dos serviços na nuvem — em vez de criar cada recurso manualmente pelo console da AWS a cada novo teste, o script provisiona ECR, ECS/Fargate, RDS, Secrets Manager, Security Groups e IAM de forma automatizada, seguindo exatamente a arquitetura desenhada. Isso não só economiza tempo do grupo como reduz erros de configuração manual.

17/08 — Consolidação e documentação

Revisei e testei o script de automação, ajustando pontos que falhavam por conta das restrições de permissão do Learner Lab. Em paralelo, organizamos toda a documentação do projeto — diagrama de arquitetura, justificativas técnicas de cada serviço escolhido e este diário de bordo — para deixar o repositório completo e pronto para apresentação.