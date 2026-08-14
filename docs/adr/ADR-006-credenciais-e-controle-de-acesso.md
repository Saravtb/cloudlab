# ADR-006 — Credenciais e controle de acesso

**Status:** aceito
**Data:** 14 de agosto de 2026
**Versão afetada:** v1.1 em diante

## Contexto

A adoção do Amazon RDS introduziu uma credencial no sistema. Até a versão
`v1.0-baseline` não havia segredo algum: a aplicação não acessava serviço
externo e não recebia task role. Com o banco, passou a existir uma senha que
precisa chegar ao container sem ser exposta.

O enunciado é categórico: credenciais, tokens, identificadores desnecessários
da conta e dados sensíveis não podem ser versionados nem documentados.

Há uma restrição do ambiente que condiciona toda esta decisão. O AWS Academy
Learner Lab concede acesso extremamente limitado ao IAM: não é possível criar
usuários, grupos nem roles, com exceção de service-linked roles. Existe uma
role pré-criada, `LabRole`, com permissões amplas, destinada a ser anexada a
recursos de serviços da AWS.

## Alternativas consideradas

**Senha em variável de ambiente da task definition.** Simples e imediato. A
senha fica em texto claro na definição, visível para qualquer pessoa com acesso
de leitura ao console do ECS, e seria versionada junto com o script que a
gera. Viola diretamente a restrição do enunciado.

**Senha em arquivo de configuração dentro da imagem.** Pior ainda: a senha
passa a integrar uma camada da imagem, permanece no registry e sobrevive a
qualquer rotação.

**AWS Secrets Manager com injeção pelo ECS.** A senha é gerada aleatoriamente,
armazenada cifrada e referenciada na task definition apenas pelo ARN. O ECS
resolve o valor no momento de iniciar o container, usando a execution role.

**Autenticação do RDS por IAM.** O banco aceitaria um token temporário
derivado da identidade da task, eliminando completamente a existência de uma
senha. É a opção tecnicamente superior.

## Decisão

Adotar o **AWS Secrets Manager**, com a senha gerada aleatoriamente pelo script
de criação e injetada no container pelo campo `secrets` da task definition.

Complementarmente, adotar **segmentação de rede por security group** como
segunda camada de controle: o acesso ao banco é restrito não por endereço IP,
mas por pertencimento ao grupo de segurança da aplicação.

## Por que a autenticação por IAM não foi adotada

A autenticação do RDS por IAM elimina a senha por completo e seria a escolha
preferencial em um ambiente com IAM disponível. Ela exige que a task role tenha
uma policy concedendo `rds-db:connect` sobre o recurso específico do banco.

Criar essa policy e anexá-la a uma role própria não é possível no Learner Lab,
que bloqueia a criação de roles e policies. A alternativa seria usar a
`LabRole`, mas ela é uma role de permissões amplas e compartilhada por todos os
recursos do ambiente — usá-la não representaria menor privilégio, apenas
deslocaria o problema.

A decisão foi, portanto, adotar a melhor opção viável no ambiente autorizado, e
registrar a opção superior como evolução conhecida. A policy que seria aplicada
está descrita ao final deste documento para demonstrar o desenho pretendido.

## Configuração adotada

A senha é gerada com `openssl rand`, com 24 caracteres, filtrando os símbolos
que o RDS não aceita. Ela nunca é escrita em arquivo do projeto nem exibida na
saída dos scripts.

O segredo `cloudlab/db` armazena, em JSON, o usuário, a senha, o nome do banco,
o endpoint e a porta. A task definition referencia apenas o ARN, sob o nome de
variável `DB_SECRET`. A execution role recupera o valor ao iniciar o container.

Executar o script de criação novamente reaproveita o segredo existente em vez
de gerar uma senha nova, o que evita divergência entre o segredo e o banco.

**Segmentação de rede.** O security group da aplicação libera apenas TCP 8000,
com origens `/32` correspondentes aos endereços de quem opera. Nenhuma regra
`0.0.0.0/0` foi criada, e nenhuma porta administrativa foi aberta.

O security group do banco libera a porta 5432 com origem definida pelo
*security group da aplicação*, não por bloco CIDR. Na prática, apenas processos
que pertencem ao grupo da task conseguem abrir conexão com o banco. Um endereço
IP correto não é suficiente. A instância também não é publicamente acessível,
o que a torna inalcançável de fora da VPC.

## Justificativa

A combinação entrega duas camadas independentes. Mesmo que a senha vazasse, o
banco continuaria inalcançável de fora da VPC e de dentro dela por qualquer
recurso que não pertença ao grupo autorizado. E mesmo que alguém obtivesse
acesso de rede, ainda precisaria da credencial.

A regra por security group é preferível à regra por endereço IP porque
sobrevive à troca de endereço da tarefa — que ocorre a cada implantação — sem
qualquer ajuste, e sem ampliar a superfície de acesso.

A distinção entre execution role e task role deixou de ser teórica nesta
versão. A execution role atua **antes** do container existir: obtém a imagem do
ECR e recupera o segredo. A task role atua **durante** a execução, e seria
usada se a aplicação chamasse APIs da AWS — o que não ocorre, já que a conexão
com o banco é uma conexão de rede comum autenticada por senha.

## Consequências

**Positivas.** Nenhuma credencial no repositório, na imagem ou na task
definition. A senha pode ser rotacionada no Secrets Manager sem alterar código.
O banco permanece isolado por construção.

**Negativas e limitações aceitas.** A `LabRole` tem permissões muito mais
amplas do que a aplicação necessita, o que contraria o princípio do menor
privilégio. Não é possível corrigir isso no ambiente autorizado.

A senha, embora protegida, continua existindo — e uma credencial de longa
duração é sempre um ativo a proteger. A autenticação por IAM eliminaria essa
categoria de risco.

A rotação automática do segredo não foi configurada, por exigir uma função
Lambda com permissões próprias.

**Evolução prevista.** Em um ambiente com IAM disponível, a decisão seria
habilitar a autenticação por IAM no RDS e anexar à task role uma policy com o
escopo abaixo, eliminando a senha e o próprio segredo:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "rds-db:connect",
      "Resource": "arn:aws:rds-db:us-east-1:<ACCOUNT_ID>:dbuser:<RESOURCE_ID>/cloudlab_app"
    }
  ]
}
```

## Verificação

Evidências `14-db-sg-origem-security-group`, `17-secrets-task-definition` e
`18-rds-configuracao` em `/evidence`, demonstrando a regra de entrada por
security group, o campo `secrets` contendo apenas o ARN e a instância sem
acesso público.
