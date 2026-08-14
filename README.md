# Projeto 1 — AWS CloudLab

Arquitetura e operação de um workload de referência na AWS.

**Unidade curricular:** Pentesting em Nuvem
**Período:** 3 a 14 de agosto de 2026
**Conta:** sandbox do AWS Academy Learner Lab · região `us-east-1`

---

## O que é este projeto

Um serviço mínimo que recebe eventos sintéticos, executado em container no
Amazon ECS com AWS Fargate, com persistência no Amazon RDS, observabilidade no
Amazon CloudWatch e implantação reproduzível por scripts versionados.

A aplicação é deliberadamente simples. Ela existe para validar decisões de
arquitetura, não para ser um projeto de desenvolvimento de software. O que está
sendo demonstrado são as escolhas, a operação e as evidências.

## Arquitetura

![Arquitetura implantada](docs/diagrama-v1.1.svg)

A equipe publica a imagem no Amazon ECR. A tarefa do ECS com Fargate roda
dentro de um security group que libera apenas a porta 8000, recebe as
requisições, grava os eventos no Amazon RDS e envia logs estruturados ao
CloudWatch. O banco fica em um security group próprio, que aceita conexão
apenas de quem pertence ao grupo da aplicação, e não tem acesso público. As
credenciais vêm do AWS Secrets Manager.

Detalhes em [`docs/arquitetura.md`](docs/arquitetura.md).

## Contrato funcional

| Rota | O que faz |
| --- | --- |
| `GET /` | Painel web com o estado do serviço e a lista de eventos |
| `GET /api` | Nome e versão do serviço |
| `GET /health` | Estado, versão, horário e situação do banco |
| `POST /events` | Recebe um evento sintético, persiste e devolve identificador |
| `GET /events` | Lista os eventos persistidos |
| `GET /docs` | Documentação OpenAPI gerada pela aplicação |

Exemplo de evento aceito:

```json
{
  "type": "operation.created",
  "source": "cloud-lab",
  "message": "Evento sintético para uso acadêmico"
}
```

## Como executar

```bash
git clone https://github.com/Saravtb/cloudlab.git
cd cloudlab/infra
chmod +x *.sh && sed -i 's/\r$//' *.sh
./01-create-rds.sh     # camada de dados, leva de 10 a 20 minutos
./deploy.sh            # publica a imagem e executa a tarefa
```

Ao terminar, sempre:

```bash
./cleanup.sh
```

O procedimento completo, com validação e diagnóstico, está no
[runbook](docs/RUNBOOK.md).

> A instância RDS é cobrada enquanto existir. O ambiente do Learner Lab pode
> não pará-la ao encerrar a sessão, e a AWS reinicia instâncias paradas após
> sete dias. Por isso o `cleanup.sh` exclui a instância em vez de pará-la.

## Organização do repositório

```
/app        aplicação, Dockerfile e frontend estático
/infra      scripts de criação, implantação e remoção
/docs       arquitetura, decisões, matriz, runbook e inventário
/evidence   evidências operacionais das duas versões
/journal    diários técnicos individuais
```

## Decisões arquiteturais

| Registro | Decisão |
| --- | --- |
| [ADR-001](docs/adr/ADR-001-plataforma-de-execucao.md) | Amazon ECS com AWS Fargate |
| [ADR-002](docs/adr/ADR-002-estrategia-de-dados.md) | Amazon RDS PostgreSQL, revendo a decisão inicial de não persistir |
| [ADR-003](docs/adr/ADR-003-observabilidade.md) | Logs estruturados e health check com sonda ativa |
| [ADR-004](docs/adr/ADR-004-automacao-e-reprodutibilidade.md) | Scripts AWS CLI versionados |
| [ADR-005](docs/adr/ADR-005-custos-e-dimensionamento.md) | Dimensionamento mínimo e remoção por sessão |
| [ADR-006](docs/adr/ADR-006-credenciais-e-controle-de-acesso.md) | Secrets Manager e segmentação por security group |

Ver também a [matriz de alternativas](docs/matriz-de-alternativas.md) e o
[inventário de recursos](docs/inventario.md).

## Versões

| Tag | O que contém |
| --- | --- |
| `v1.0-baseline` | Workload sem persistência, observabilidade e remoção completa |
| `v1.2` | Persistência no RDS, frontend, Secrets Manager e recuperação automática |

## Decisões de segurança aplicadas

- Container executa como UID 10001, não root.
- Repositório ECR privado, com tags imutáveis e varredura na publicação.
- Security group da aplicação libera apenas TCP 8000, com origens `/32`.
  Nenhuma regra `0.0.0.0/0` e nenhuma porta administrativa.
- Banco sem acesso público, alcançável apenas de dentro da VPC e apenas por
  quem pertence ao security group da aplicação.
- Senha gerada aleatoriamente, armazenada cifrada no Secrets Manager e
  referenciada apenas por ARN. Nenhuma credencial versionada.
- Identificadores de conta mascarados em todas as evidências.

## Evidências

O diretório [`/evidence`](evidence/) reúne as evidências das duas versões, cada
uma com inventário próprio explicando o que cada arquivo comprova. Inclui o
registro de um teste deliberado de falha: a instância RDS foi parada com a
aplicação em execução, para verificar o comportamento diante da
indisponibilidade da dependência.

A remoção dos recursos está registrada em
[`evidence/v1.1/25-cleanup.txt`](evidence/v1.1/25-cleanup.txt), com inventário
residual vazio.

## Limitações conhecidas

O ambiente do Learner Lab não permite criar roles ou policies de IAM. Isso
impediu adotar a autenticação do RDS por IAM, que eliminaria a senha; a opção
pretendida está documentada no ADR-006.

Não há Application Load Balancer, portanto o endereço público muda a cada
implantação. Não há dashboards nem alarmes do CloudWatch. A tarefa é autônoma,
sem auto-recuperação em caso de falha.

O armazenamento do banco não está criptografado em repouso: os dados são
sintéticos e acadêmicos, sem requisito de confidencialidade.
