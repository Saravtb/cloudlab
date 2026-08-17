Diário de Bordo — Projeto AWS CloudLab
05/08 — Inscrição na AWS Academy

Uma das primeiras coisas que aconteceram no projeto foi a inscrição da turma na AWS Academy, feita pelo professor. Logo em seguida, ficamos com acesso liberado à plataforma e aos cursos disponíveis nela, o que marcou o início oficial do nosso contato com o ambiente e os conteúdos formais da AWS.

06/08 — Kickoff do projeto

Com o acesso à AWS Academy já liberado, demos início oficial ao projeto em grupo. Discutimos o escopo geral do trabalho — uma aplicação containerizada rodando na infraestrutura da AWS — e dividimos as primeiras responsabilidades entre os integrantes. Nesse primeiro momento, o foco foi entender o que seria exigido pela disciplina e mapear quais tecnologias precisaríamos estudar do zero: Docker, containers e os serviços da AWS voltados para computação em nuvem.

07/08 — Primeiro contato com a AWS

Começamos a explorar o ambiente do AWS Academy Learner Lab, entendendo suas limitações específicas (permissões restritas de IAM, impossibilidade de criar roles customizadas, uso obrigatório da LabRole). Nesse dia, o grupo todo navegou pelo console da AWS para reconhecer a interface e identificar quais serviços estariam disponíveis para o projeto.

08/08 e 09/08 — Explorando os serviços da AWS

Dedicamos esses dias a estudar, em conjunto, os principais serviços que a AWS oferece para hospedar aplicações: EC2, ECS, Fargate, S3, RDS e DynamoDB. Discutimos as diferenças entre rodar uma aplicação em uma instância EC2 tradicional versus uma abordagem serverless, e entendemos por que o Fargate se encaixava melhor nas restrições do Learner Lab.

10/08 — Finalização do desenho da arquitetura

Fiquei responsável por conduzir a parte de arquitetura do projeto: a partir da montagem da estrutura, selecionei quais serviços específicos da AWS seriam utilizados e desenhei como eles se conectariam entre si — Amazon ECR, ECS com Fargate, banco de dados e CloudWatch para logs. Nesse dia, o desenho da arquitetura do projeto foi finalizado e apresentado ao grupo para validação.

11/08, 12/08 e 13/08 — Montagem do projeto em conjunto com o grupo

Com a arquitetura já definida, esses três dias foram dedicados à montagem prática do projeto em conjunto com todo o grupo. Aprendemos e aplicamos os conceitos de Docker — imagem, container, Dockerfile e camadas (layers) — e construímos nossa API já pensando em rodá-la de forma containerizada, pela facilidade de montagem e pela portabilidade que essa abordagem oferece.

A API foi construída e testada localmente primeiro, dentro do container, e só depois de validada localmente foi enviada (push) para um repositório de imagens — no caso, o Amazon ECR, e não o Docker Hub, já que o ECR se integra nativamente aos demais serviços da AWS usados no projeto (ECS/Fargate e IAM), facilitando o restante do fluxo de deploy.

14/08 — Apresentação para o professor

Realizamos a apresentação do projeto para o professor, mostrando a arquitetura desenhada, o funcionamento da API containerizada e o fluxo completo dos serviços AWS utilizados.