# Diário de bordo — Luiz Fernando

**Unidade curricular:** Pentesting em Nuvem
**Projeto:** Projeto 1 — AWS CloudLab
**Período:** 12 a 14 de agosto de 2026

## 12 de agosto — Início do projeto

Começamos o desenvolvimento do projeto definindo a proposta da aplicação e organizando as primeiras tarefas entre os integrantes do grupo.

Participei das discussões sobre a estrutura da aplicação e acompanhei a preparação do ambiente de desenvolvimento. Também começamos a trabalhar na aplicação em Python e nas funcionalidades que seriam utilizadas durante os testes.

Nessa primeira etapa, o principal objetivo foi entender o que precisava ser desenvolvido e como a aplicação seria posteriormente preparada para funcionar na AWS.

## 13 de agosto — Docker e AWS

Com a aplicação em desenvolvimento, começamos a preparar o projeto para ser executado através de containers.

Participei da criação e dos testes da imagem Docker, entendendo melhor como o código da aplicação e suas dependências ficam reunidos em um ambiente que pode ser executado de forma padronizada.

Depois disso, trabalhamos na implantação da aplicação na AWS. Utilizamos o Amazon ECR para armazenar a imagem e o Amazon ECS com Fargate para executar o container.

Durante essa etapa, tivemos que configurar portas, regras de acesso e verificar se o serviço estava realmente disponível externamente. Fizemos diversos testes para confirmar que a aplicação estava funcionando corretamente depois da implantação.

Também começamos a acompanhar os recursos criados na AWS e a registrar as evidências necessárias para a documentação do projeto.

## 14 de agosto — Integração, testes e finalização

No último dia, continuamos os trabalhos de integração da aplicação com os recursos da AWS.

Uma das etapas foi a utilização do Amazon RDS para permitir a persistência dos dados da aplicação. Trabalhamos também nas configurações de segurança e comunicação entre os serviços, utilizando Security Groups para controlar os acessos.

Outra parte importante foi a integração com o frontend. Participamos dos ajustes necessários para que a interface conseguisse se comunicar com a API que estava sendo executada na AWS.

Durante os testes, encontramos alguns problemas de configuração e comunicação. Fomos analisando os erros em conjunto e realizando os ajustes necessários até conseguir utilizar a aplicação através do endereço público.

No final do dia, realizamos os testes gerais do projeto, verificando o funcionamento da aplicação, da API, do container, do banco de dados e da comunicação com o frontend. Também organizamos a documentação e as evidências para finalizar a entrega.

## O que aprendi durante o projeto

Durante esses dias, consegui compreender melhor todo o caminho entre desenvolver uma aplicação e disponibilizá-la em um ambiente de nuvem.

Na prática, tive contato com diferentes tecnologias e serviços, principalmente Python, Docker, Amazon ECR, ECS, Fargate, RDS e Security Groups.

Também entendi melhor que uma aplicação na nuvem depende de várias partes funcionando juntas. Não basta o código estar correto: é necessário configurar corretamente o container, a rede, as permissões, o banco de dados e a comunicação entre os serviços.

Outro ponto importante foi o trabalho em equipe. O projeto foi desenvolvido em conjunto desde o início, com os integrantes participando das diferentes etapas, ajudando uns aos outros na resolução dos problemas e tomando as decisões necessárias durante o desenvolvimento.

Ao finalizar o projeto, fiquei com uma visão mais prática de como uma aplicação pode ser desenvolvida, containerizada, implantada e disponibilizada utilizando serviços de computação em nuvem.
