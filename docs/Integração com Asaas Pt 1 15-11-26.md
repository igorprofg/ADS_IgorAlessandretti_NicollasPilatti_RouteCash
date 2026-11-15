# Relatório de Desenvolvimento — Integração Asaas no Route Cash

**Projeto:** Route Cash  
**Módulo:** Backend — Assinaturas e Pagamentos  
**Tecnologias principais:** NestJS, Prisma ORM, PostgreSQL, JWT e API Asaas  
**Ambiente de pagamento:** Asaas Sandbox  
**Data:** 15/11/2026
**Responsável**: Nicollas Pilatti

---

## 1. Objetivo

Esta etapa do desenvolvimento teve como objetivo iniciar e validar a integração do Route Cash com o **Asaas**, permitindo que um motorista autenticado escolha um plano de assinatura e seja direcionado para um checkout recorrente de pagamento.

A integração foi planejada de forma híbrida para preservar dois fluxos de assinatura:

- **Fluxo automático via Asaas**, utilizado nas contratações realizadas pelo próprio motorista;
- **Fluxo manual**, mantido para operações administrativas e liberações realizadas pelo administrador.

Nesta etapa, foi concluído e validado o fluxo até a **criação e abertura do Checkout Asaas em ambiente Sandbox**.

A ativação automática da assinatura após o pagamento ainda depende da implementação do **Webhook do Asaas**, que será realizada na próxima etapa.

---

## 2. Resultado alcançado

Ao final desta etapa, o fluxo funcional validado ficou da seguinte forma:

```text
Usuário autenticado
        ↓
Escolhe um plano
        ↓
Backend verifica/cria Customer no Asaas
        ↓
Backend sincroniza dados cadastrais e endereço
        ↓
Cria assinatura local como PENDENTE
        ↓
Cria Checkout recorrente no Asaas
        ↓
Salva o ID do Checkout no banco
        ↓
Retorna a URL pública do Checkout
        ↓
Usuário abre o Checkout Sandbox
```

O Checkout foi criado com sucesso e a página pública do Asaas foi aberta corretamente no navegador.

---

## 3. Arquitetura adotada para assinaturas

Foi definida uma estratégia híbrida para permitir tanto assinaturas automáticas quanto manuais.

### 3.1. Assinatura manual

O fluxo manual permanece disponível para operações administrativas.

```text
Administrador
    ↓
Cria/libera assinatura
    ↓
origem = MANUAL
    ↓
situacao = ATIVA
```

Este fluxo não depende do Asaas.

### 3.2. Assinatura via Asaas

O novo fluxo automático utiliza o gateway de pagamento.

```text
Motorista
    ↓
Seleciona plano
    ↓
Route Cash cria assinatura
    ↓
origem = ASAAS
situacao = PENDENTE
    ↓
Checkout Asaas
    ↓
Pagamento
    ↓
Webhook
    ↓
situacao = ATIVA
```

A assinatura não deve ser considerada ativa no momento da criação do checkout. A ativação acontecerá somente após a confirmação financeira enviada pelo Asaas.

---

## 4. Configuração do ambiente Asaas

Foi utilizada uma conta no **Asaas Sandbox** para desenvolvimento e testes.

O backend passou a utilizar variáveis de ambiente para evitar que credenciais sejam armazenadas diretamente no código.

Exemplo de configuração:

```env
ASAAS_BASE_URL=https://api-sandbox.asaas.com/v3
ASAAS_API_KEY=CHAVE_PRIVADA_DO_SANDBOX
ASAAS_USER_AGENT=RouteCash/1.0

ASAAS_CHECKOUT_SUCCESS_URL=https://example.com/routecash/sucesso
ASAAS_CHECKOUT_CANCEL_URL=https://example.com/routecash/cancelado
ASAAS_CHECKOUT_EXPIRED_URL=https://example.com/routecash/expirado
```

A chave real da API foi mantida somente no `.env` e não deve ser inserida no `.env.example`, Git, documentação, frontend ou aplicativo mobile.

---

## 5. Instalação e configuração do ConfigModule

Durante a integração foi necessário adicionar o `@nestjs/config` ao projeto.

Inicialmente, a instalação sem versão específica tentou utilizar uma versão incompatível com a versão atual do NestJS do backend:

```powershell
npm install @nestjs/config
```

A dependência foi então instalada utilizando uma versão compatível com o NestJS 10:

```powershell
npm install @nestjs/config@3.3.0
```

Após o ajuste, o `ConfigService` passou a ser injetado normalmente no `AsaasService`.

---

## 6. Estrutura do módulo Asaas

Foi criado/utilizado o módulo:

```text
src/asaas/
```

Com os principais arquivos:

```text
src/asaas/asaas.module.ts
src/asaas/asaas.controller.ts
src/asaas/asaas.service.ts
src/asaas/asaas.types.ts
```

O `AsaasModule` importa `ConfigModule` e `PrismaModule` e exporta `AsaasService`, permitindo sua utilização pelo módulo de assinaturas.

---

## 7. Teste inicial de conexão com o Asaas

Foi implementado um endpoint temporário para validar a autenticação com a API:

```text
GET /asaas/teste
```

O teste retornou sucesso no ambiente Sandbox e confirmou que:

- a API Key estava correta;
- a URL do ambiente Sandbox estava correta;
- o backend conseguia se comunicar com a API do Asaas;
- o `User-Agent` estava sendo enviado;
- o endpoint de Customers estava acessível.

Após esse teste, a autenticação entre Route Cash e Asaas foi considerada validada.

---

## 8. Alterações no banco de dados

A integração exigiu alterações principalmente nos modelos:

```text
Usuario
Assinatura
Pagamento
EventoWebhook
```

---

## 9. Alterações no model Usuario

O usuário passou a possuir dados necessários para integração com o gateway de pagamento.

Foram adicionados campos como:

```prisma
cpf_cnpj String? @unique @db.VarChar(14)
celular String? @db.VarChar(20)
cep String? @db.VarChar(8)
logradouro String? @db.VarChar(150)
numero_endereco String? @db.VarChar(20)
complemento String? @db.VarChar(100)
bairro String? @db.VarChar(100)
asaas_customer_id String? @unique @db.VarChar(100)
```

Os campos foram mantidos opcionais no banco para evitar quebra imediata de usuários antigos. Entretanto, antes de realizar uma contratação via Asaas, o backend verifica se os dados obrigatórios foram preenchidos.

---

## 10. Motivo da inclusão do endereço

No primeiro teste de criação do Checkout, o Asaas retornou erro HTTP `400` informando ausência dos seguintes dados no Customer:

```text
address
addressNumber
postalCode
province
city
```

O Customer criado anteriormente possuía apenas nome, CPF/CNPJ, e-mail e celular.

Por esse motivo, foram adicionados dados de endereço ao cadastro local do usuário e implementada a sincronização destes dados com o Customer existente no Asaas.

---

## 11. Migration dos campos de endereço

Após a alteração do `schema.prisma`, foram utilizados os comandos:

```powershell
npx prisma format
npx prisma validate
npx prisma migrate dev --name adicionar_endereco_usuario_asaas
npx prisma generate
```

Os novos campos passaram a ser exibidos corretamente no Prisma Studio após a atualização/reinicialização do ambiente.

O usuário utilizado nos testes foi então preenchido com CEP, logradouro, número, bairro e complemento, quando aplicável.

---

## 12. Problema de bloqueio do Prisma no Windows

Durante o `prisma generate`, ocorreu o erro:

```text
EPERM: operation not permitted, rename
node_modules\.prisma\client\query_engine-windows.dll.node.tmp...
```

O erro ocorreu porque o arquivo do Prisma Engine estava sendo utilizado por algum processo Node ativo no Windows.

A correção consistiu em:

```powershell
taskkill /F /IM node.exe
Remove-Item -Recurse -Force node_modules\.prisma -ErrorAction SilentlyContinue
npx prisma generate
```

Após liberar o arquivo, o Prisma Client foi regenerado com sucesso. Esse problema não estava relacionado ao schema ou à migration, mas ao bloqueio do arquivo `.dll` pelo sistema operacional.

---

## 13. Alterações no model Assinatura

A assinatura passou a suportar o fluxo de pagamento externo.

Os principais campos relacionados ao Asaas são:

```prisma
origem OrigemAssinatura @default(MANUAL)
asaas_checkout_id String? @unique @db.VarChar(100)
asaas_subscription_id String? @unique @db.VarChar(100)
```

Também foi adicionada a situação `PENDENTE` ao enum:

```prisma
enum SituacaoAssinatura {
  ATIVA
  SUSPENSA
  CANCELADA
  PENDENTE
}
```

No estado final do schema, novas assinaturas podem utilizar:

```prisma
situacao SituacaoAssinatura @default(PENDENTE)
```

O serviço de assinatura via Asaas informa explicitamente:

```text
origem = ASAAS
situacao = PENDENTE
```

---

## 14. Problema encontrado na migration do enum PENDENTE

A primeira tentativa de migration apresentou erro PostgreSQL/Prisma porque a mesma migration adicionava o valor `PENDENTE` ao enum e tentava utilizá-lo imediatamente como valor default.

A solução foi dividir a alteração em duas etapas.

### Primeira migration

Foi adicionado `PENDENTE` ao enum, mantendo temporariamente:

```prisma
@default(ATIVA)
```

### Segunda migration

Depois que o novo valor já existia no banco, o default foi alterado para:

```prisma
@default(PENDENTE)
```

Dessa forma, as migrations foram aplicadas corretamente sem necessidade de recriar toda a estrutura do banco.

---

## 15. Origem da assinatura

Foi criado/utilizado o enum:

```prisma
enum OrigemAssinatura {
  MANUAL
  ASAAS
}
```

`MANUAL` é utilizado quando o administrador cria ou libera a assinatura diretamente. `ASAAS` é utilizado quando a contratação é realizada pelo checkout integrado.

Essa separação permite manter os dois fluxos sem comprometer registros antigos.

---

## 16. Model Pagamento

O pagamento possui suporte ao identificador externo:

```prisma
asaas_payment_id String? @unique @db.VarChar(100)
```

O campo será utilizado principalmente na próxima etapa, quando os Webhooks forem processados.

Situações existentes:

```prisma
enum SituacaoPagamento {
  PAGO
  PENDENTE
  VENCIDO
}
```

O registro automático de pagamentos ainda não foi concluído nesta etapa.

---

## 17. Model EventoWebhook

A tabela `EventoWebhook` foi mantida/preparada para registrar eventos recebidos do Asaas.

O objetivo principal é garantir **idempotência**.

```text
Asaas envia evt_123
        ↓
Route Cash processa
        ↓
salva evt_123
        ↓
Asaas reenvia evt_123
        ↓
Route Cash detecta que já foi processado
        ↓
não executa novamente
```

Isso será importante para impedir pagamento duplicado, ativação duplicada, atualização duplicada, cancelamento duplicado e processamento repetido de Webhooks.

---

## 18. Implementação de Customer no Asaas

Foi implementado no `AsaasService` o fluxo de obtenção ou criação de Customer.

Método principal:

```text
obterOuCriarCliente(usuarioId)
```

Fluxo:

```text
Busca usuário
    ↓
Valida CPF/CNPJ e endereço
    ↓
possui asaas_customer_id?
    ├── SIM → atualiza e reutiliza Customer
    │
    └── NÃO
          ↓
      busca por externalReference
          ↓
      encontrou?
       ├── SIM → vincula ao usuário e atualiza
       │
       └── NÃO → cria novo Customer
```

---

## 19. Prevenção de Customers duplicados

A criação do Customer foi testada mais de uma vez com o mesmo usuário.

No primeiro teste:

```text
Customer não existia
→ Customer criado no Asaas
→ ID salvo em usuario.asaas_customer_id
```

No segundo teste:

```text
asaas_customer_id já existia
→ Customer reutilizado
→ nenhum novo Customer criado
```

Também foi implementada busca por:

```text
externalReference = id_usuario
```

para recuperar um Customer do Asaas caso o vínculo local seja perdido.

---

## 20. Sincronização do endereço do Customer

Quando o usuário já possui `asaas_customer_id`, o backend não cria outro Customer.

Em vez disso, é executada uma atualização:

```text
PUT /customers/{customerId}
```

Os dados sincronizados incluem:

```text
name
cpfCnpj
email
mobilePhone
postalCode
address
addressNumber
complement
province
externalReference
```

Assim, os dados locais necessários são atualizados antes da criação do Checkout.

---

## 21. Validação dos dados antes do Asaas

O backend passou a validar os dados antes de tentar criar ou atualizar um Customer.

São verificados:

```text
CPF/CNPJ
CEP
logradouro
número do endereço
bairro
```

O CPF/CNPJ é normalizado para somente números e deve possuir 11 dígitos para CPF ou 14 dígitos para CNPJ.

O CEP é normalizado e deve possuir 8 dígitos.

Caso algum dado obrigatório esteja ausente, o Route Cash retorna uma mensagem de validação antes de enviar uma requisição inválida ao gateway.

---

## 22. Integração do AssinaturasModule com AsaasModule

O módulo de assinaturas passou a importar `PrismaModule` e `AsaasModule`.

Isso permite que o `AssinaturasService` receba:

```typescript
private readonly prisma: PrismaService
private readonly asaasService: AsaasService
```

por injeção de dependência.

Após essa alteração, o backend iniciou sem erros de dependência.

---

## 23. Endpoint para contratação via Asaas

Foi criado um endpoint de contratação automática protegido por JWT:

```text
POST /assinaturas/asaas
```

O endpoint utiliza o usuário autenticado extraído do token.

O corpo enviado é:

```json
{
  "id_plano": "UUID_DO_PLANO"
}
```

Não é necessário enviar manualmente o ID do usuário.

---

## 24. Autenticação utilizada nos testes

Inicialmente foi tentada a rota:

```text
POST /auth/login
```

O backend retornou:

```text
404 Not Found
Cannot POST /auth/login
```

Foi então verificada a estrutura real dos controllers do projeto.

A rota correta encontrada foi:

```text
POST /autenticacao/login
```

O login retorna:

```json
{
  "access_token": "JWT..."
}
```

Esse `access_token` foi utilizado como `Bearer Token` nas chamadas protegidas.

---

## 25. Testes utilizando Postman

O Postman foi instalado e utilizado para validar o fluxo.

### Login

```http
POST http://localhost:3000/autenticacao/login
```

Body:

```json
{
  "email": "EMAIL_DO_USUARIO",
  "senha": "SENHA_DO_USUARIO"
}
```

### Contratação pelo Asaas

```http
POST http://localhost:3000/assinaturas/asaas
```

Authorization:

```text
Bearer Token
```

Body:

```json
{
  "id_plano": "UUID_DO_PLANO"
}
```

---

## 26. Primeiro erro no Postman

Ao configurar a URL do login, inicialmente foi informado:

```text
POST http://localhost:3000/autenticacao/login
```

dentro do campo de URL do Postman.

Como o método `POST` já estava selecionado separadamente, o Postman tentou interpretar `post http:` como protocolo.

O erro apresentado foi:

```text
Invalid protocol: post http:
```

A correção foi informar somente:

```text
http://localhost:3000/autenticacao/login
```

no campo de URL.

---

## 27. Criação da assinatura local

Ao solicitar uma contratação via Asaas, o backend cria a assinatura local antes da confirmação financeira.

O estado observado no teste foi:

```text
situacao = PENDENTE
origem = ASAAS
data_inicio = null
data_vencimento = null
asaas_subscription_id = null
```

Esse comportamento é esperado. Enquanto o pagamento não for confirmado, as datas efetivas e o identificador da assinatura recorrente permanecem sem preenchimento.

---

## 28. Proteção contra checkout duplicado

O serviço de assinaturas verifica se já existe uma assinatura em aberto para o usuário.

Estados considerados em aberto incluem:

```text
PENDENTE
ATIVA
SUSPENSA
```

Quando já existe uma assinatura `PENDENTE`, com origem `ASAAS`, mesmo plano e `asaas_checkout_id` preenchido, o backend pode reutilizar o checkout existente em vez de criar uma nova assinatura local.

Isso evita duplicidades causadas por múltiplos cliques ou reenvio da mesma contratação.

---

## 29. Criação do Checkout recorrente

Foi implementado o método:

```text
criarCheckoutAssinatura(...)
```

no `AsaasService`.

O Checkout é criado com cobrança recorrente:

```text
billingTypes = CREDIT_CARD
chargeTypes = RECURRENT
```

O período do plano Route Cash é convertido para o ciclo correspondente.

Exemplo:

```text
MENSAL → MONTHLY
ANUAL → YEARLY
```

Também foram previstos ciclos semanal, quinzenal, bimestral, trimestral e semestral.

---

## 30. Dados enviados ao Checkout

O payload do Checkout inclui:

```text
billingTypes
chargeTypes
minutesToExpire
externalReference
customer
callback
items
subscription
```

O `externalReference` utiliza o identificador da assinatura local:

```text
Assinatura Route Cash
        ↓
id_assinatura
        ↓
externalReference do Checkout
```

Isso permitirá relacionar eventos futuros do Asaas à assinatura correta.

---

## 31. Plano utilizado no teste

Foi testado um plano mensal com:

```text
nome = Plano Mensal
valor = R$ 19,90
periodo_cobranca = MENSAL
```

Os benefícios cadastrados também foram enviados como descrição do item no Checkout.

---

## 32. Primeiro Checkout criado com sucesso

Após a correção do endereço, a API retornou uma assinatura com:

```text
situacao = PENDENTE
origem = ASAAS
asaas_checkout_id preenchido
checkout_reutilizado = false
```

Isso confirmou que o Customer foi aceito, a assinatura local foi criada, o Asaas aceitou o Checkout recorrente e o ID do Checkout foi salvo no Route Cash.

---

## 33. Problema com a URL pública do Checkout

Inicialmente, o backend montava manualmente a URL utilizando:

```text
https://asaas.com/checkoutSession/show?id={checkoutId}
```

O ID era válido, porém a página aberta retornava:

```text
Página não encontrada
```

A criação do Checkout não havia falhado. O problema estava apenas na URL pública utilizada para acessá-lo.

---

## 34. Identificação do link real retornado pelo Asaas

Foi adicionada inspeção da resposta do Checkout no backend.

O Asaas retornou:

```text
id
status
link
```

No teste Sandbox, o formato real do link retornado foi semelhante a:

```text
https://sandbox.asaas.com/000/checkoutSession/show/{checkoutId}
```

O status retornado foi:

```text
ACTIVE
```

A partir disso, o backend passou a dar preferência ao campo `checkout.link` retornado diretamente pelo Asaas.

---

## 35. Ajuste de tipagem do Checkout

Durante esse ajuste ocorreu erro TypeScript:

```text
Property 'link' does not exist on type 'AsaasCheckout'
```

Para evitar quebra da tipagem existente, foi utilizado um tipo complementar:

```typescript
type AsaasCheckoutComLink = AsaasCheckout & {
  link?: string;
  status?: string;
};
```

Com isso, o `AsaasService` consegue utilizar `checkout.link` e `checkout.status` mantendo compatibilidade com o tipo existente.

---

## 36. Geração de um novo Checkout para teste

Como a assinatura já possuía um `asaas_checkout_id`, o backend reutilizaria o Checkout anterior.

Para validar a nova URL no Sandbox, foi utilizado o Prisma Studio e apagado somente o campo:

```text
asaas_checkout_id
```

da assinatura de teste, mantendo os demais dados, inclusive `situacao = PENDENTE` e `origem = ASAAS`.

Ao reenviar a contratação, o backend identificou uma assinatura pendente sem Checkout e criou uma nova sessão no Asaas.

---

## 37. Checkout final validado

O novo Checkout retornou no log:

```text
status = ACTIVE
ambiente = SANDBOX
link = URL pública do Sandbox
```

A URL retornada diretamente pelo Asaas foi aberta no navegador.

Resultado:

```text
Checkout Asaas carregado com sucesso.
```

Com isso, a criação e abertura do Checkout foram consideradas validadas.

---

## 38. Estado atual da integração

### Concluído

- conexão do backend com Asaas Sandbox;
- configuração por variáveis de ambiente;
- integração do `ConfigService`;
- criação do `AsaasModule`;
- criação e reutilização de Customer;
- proteção contra Customer duplicado;
- vínculo `Usuario → asaas_customer_id`;
- inclusão de CPF/CNPJ e celular;
- inclusão dos dados de endereço;
- atualização de Customer existente;
- validação dos dados antes da contratação;
- suporte a assinatura `PENDENTE`;
- diferenciação `MANUAL` e `ASAAS`;
- criação de assinatura local pendente;
- criação de Checkout recorrente;
- salvamento de `asaas_checkout_id`;
- obtenção do link público real do Checkout;
- abertura do Checkout Sandbox no navegador;
- autenticação JWT do endpoint;
- teste completo via Postman.

### Ainda não concluído

- pagamento Sandbox concluído e reconciliado automaticamente;
- Webhook Asaas;
- autenticação/validação do Webhook;
- registro automático do pagamento;
- preenchimento de `asaas_payment_id`;
- preenchimento de `asaas_subscription_id`;
- transição automática `PENDENTE → ATIVA`;
- preenchimento automático de `data_inicio`;
- cálculo/preenchimento de `data_vencimento`;
- tratamento de pagamento vencido;
- tratamento de cancelamento;
- sincronização de cancelamento com a assinatura do Asaas;
- exposição pública temporária do backend local para recebimento do Webhook;
- testes de idempotência dos eventos.

---

## 39. Próxima etapa — Webhook

A próxima etapa deverá implementar um endpoint público para receber eventos do Asaas.

```text
Usuário paga no Checkout
        ↓
Asaas confirma pagamento
        ↓
Asaas envia Webhook
        ↓
Route Cash recebe evento
        ↓
verifica autenticação
        ↓
verifica idempotência
        ↓
localiza assinatura
        ↓
registra pagamento
        ↓
salva IDs do Asaas
        ↓
PENDENTE → ATIVA
        ↓
preenche datas
```

O Webhook não deverá utilizar `JwtAuthGuard`, pois a chamada será realizada pelo próprio Asaas, e não por um usuário autenticado do Route Cash.

Deverá ser utilizado um mecanismo próprio para validar a requisição.

---

## 40. Idempotência do Webhook

A tabela `EventoWebhook` deverá ser utilizada antes de qualquer alteração financeira.

```text
Recebe evento
    ↓
busca id_evento
    ↓
já existe?
 ┌───────┴───────┐
 SIM             NÃO
 ↓                ↓
ignora       processa evento
                  ↓
             salva id_evento
```

Esse comportamento é necessário porque gateways podem reenviar eventos.

---

## 41. Backend local e Webhook externo

O backend atualmente está sendo executado localmente em:

```text
http://localhost:3000
```

O Asaas não consegue acessar diretamente `localhost`.

Para os testes reais do Webhook Sandbox será necessário disponibilizar temporariamente o endpoint por uma URL pública, utilizando posteriormente um túnel de desenvolvimento ou outro mecanismo apropriado.

Essa configuração ainda não foi realizada nesta etapa.

---

## 42. Arquivos principais alterados ou envolvidos

```text
prisma/schema.prisma

src/asaas/asaas.module.ts
src/asaas/asaas.controller.ts
src/asaas/asaas.service.ts
src/asaas/asaas.types.ts

src/assinaturas/assinaturas.module.ts
src/assinaturas/assinaturas.controller.ts
src/assinaturas/assinaturas.service.ts

src/autenticacao/autenticacao.controller.ts

.env
```

Também foram geradas migrations Prisma relacionadas à integração Asaas, default `PENDENTE`, dados de pagamento do usuário e endereço.

---

## 43. Principais endpoints utilizados

### Autenticação

```http
POST /autenticacao/login
```

### Teste da API Asaas

```http
GET /asaas/teste
```

### Teste de Customer

```http
POST /asaas/customer/:usuarioId
```

Endpoint utilizado durante desenvolvimento/testes.

### Contratação manual

```http
POST /assinaturas
```

### Contratação pelo Asaas

```http
POST /assinaturas/asaas
```

Este endpoint é protegido por JWT e identifica o usuário pelo token.

---

## 44. Problemas encontrados e correções

| Problema | Causa identificada | Correção |
|---|---|---|
| `@nestjs/config` incompatível | versão mais nova incompatível com NestJS 10 | instalação de `@nestjs/config@3.3.0` |
| erro de dependência do `ConfigService` | `ConfigModule` não disponível no módulo | importação do `ConfigModule` no `AsaasModule` |
| migration do enum `PENDENTE` falhou | novo valor do enum utilizado como default na mesma transação | divisão da alteração em duas migrations |
| Prisma `EPERM` no Windows | engine `.dll` bloqueada por processo Node | encerramento dos processos e regeneração do Prisma Client |
| `POST /auth/login` retornou 404 | rota real possui controller `autenticacao` | uso de `/autenticacao/login` |
| Postman retornou `Invalid protocol` | `POST` foi escrito dentro do campo URL | remoção do método do campo de URL |
| Checkout retornou erro de endereço | Customer sem endereço completo | inclusão e sincronização dos campos de endereço |
| Checkout criado mas página não abriu | URL pública montada manualmente estava incorreta para o Sandbox | utilização do `link` retornado pelo Asaas |
| TypeScript não reconheceu `checkout.link` | tipo `AsaasCheckout` antigo | criação de tipo complementar com `link?` e `status?` |
| checkout antigo era reutilizado | `asaas_checkout_id` já estava salvo | limpeza controlada do campo no ambiente de teste e geração de nova sessão |

---

## 45. Testes realizados

### Teste 1 — Autenticação da API Asaas

**Resultado:** aprovado.

```text
Backend conseguiu consultar Customers no Sandbox.
```

### Teste 2 — Criação de Customer

**Resultado:** aprovado.

```text
Customer criado e asaas_customer_id salvo no usuário.
```

### Teste 3 — Reenvio da criação de Customer

**Resultado:** aprovado.

```text
Customer existente reutilizado.
Nenhum Customer duplicado foi criado.
```

### Teste 4 — Checkout sem endereço

**Resultado:** falhou conforme esperado.

O Asaas rejeitou a criação por ausência dos dados de endereço. A falha permitiu identificar os campos necessários.

### Teste 5 — Sincronização de endereço

**Resultado:** aprovado.

Após preencher os dados no Route Cash, o Customer existente foi atualizado.

### Teste 6 — Criação da assinatura pendente

**Resultado:** aprovado.

```text
situacao = PENDENTE
origem = ASAAS
```

### Teste 7 — Criação de Checkout recorrente

**Resultado:** aprovado.

O Asaas retornou `id`, `status = ACTIVE` e `link`.

### Teste 8 — Abertura da primeira URL construída manualmente

**Resultado:** reprovado.

A página retornou `Página não encontrada`.

### Teste 9 — Abertura do link real retornado pelo Asaas

**Resultado:** aprovado.

O Checkout Sandbox abriu corretamente no navegador.

---

## 46. Estado dos dados após a criação do Checkout

Enquanto não houver confirmação de pagamento, a assinatura deve permanecer:

```text
situacao = PENDENTE
origem = ASAAS
data_inicio = null
data_vencimento = null
asaas_checkout_id = preenchido
asaas_subscription_id = null
```

Esse é o comportamento correto para o ponto atual da integração.

A presença de um Checkout ativo não deve liberar automaticamente o acesso pago ao sistema.

---

## 47. Regra de ativação planejada

A assinatura somente deverá passar para:

```text
ATIVA
```

quando o backend receber e validar um evento de pagamento do Asaas.

A confirmação não deverá depender apenas de redirecionamento do navegador, `successUrl` ou retorno visual do Checkout. O backend deverá possuir sua própria confirmação servidor-servidor.

---

## 48. Segurança

Durante esta etapa foram mantidas as seguintes decisões:

- API Key armazenada somente no backend;
- API Key não enviada ao frontend ou mobile;
- contratação vinculada ao usuário autenticado pelo JWT;
- ID de usuário não precisa ser informado manualmente na rota de contratação;
- dados sensíveis não devem ser gravados em logs;
- o log de desenvolvimento do Checkout exibe apenas informações operacionais necessárias;
- o fluxo de Webhook deverá possuir autenticação própria;
- eventos do Webhook deverão possuir controle de idempotência.

---

## 49. Situação final desta etapa

```text
[OK] Login JWT
[OK] Plano existente
[OK] Customer Asaas
[OK] Reutilização de Customer
[OK] Dados de endereço
[OK] Atualização do Customer
[OK] Assinatura local PENDENTE
[OK] Checkout recorrente
[OK] Checkout ID salvo
[OK] Link público retornado pelo Asaas
[OK] Checkout Sandbox aberto no navegador

[PENDENTE] Pagamento de teste
[PENDENTE] Webhook
[PENDENTE] Registro automático do pagamento
[PENDENTE] Ativação automática da assinatura
[PENDENTE] asaas_subscription_id
[PENDENTE] Tratamento de eventos posteriores
```

---

## 50. Conclusão

A primeira fase da integração financeira do Route Cash com o Asaas foi concluída com sucesso.

O backend já consegue autenticar na API Sandbox, manter um Customer associado a cada usuário, sincronizar os dados cadastrais necessários, criar uma assinatura local pendente e gerar um Checkout recorrente válido.

Também foram tratados problemas importantes encontrados durante a implementação, incluindo incompatibilidade de dependências, migrations de enum no PostgreSQL, bloqueio do Prisma Engine no Windows, ausência de endereço no Customer e alteração da estrutura da URL pública do Checkout.

O teste final confirmou que o Checkout retornado pela API do Asaas está ativo e pode ser aberto normalmente no ambiente Sandbox.

A integração ainda não deve ser considerada concluída financeiramente, pois a assinatura permanece corretamente em estado `PENDENTE` até que o pagamento seja confirmado.

A próxima etapa é implementar o **Webhook do Asaas**, responsável por receber os eventos financeiros, impedir processamento duplicado, registrar o pagamento e ativar automaticamente a assinatura no Route Cash.

---

## 51. Próximos passos

1. Criar módulo/controller/service de Webhook do Asaas.
2. Definir token/autenticação específica do Webhook.
3. Criar endpoint público sem `JwtAuthGuard`.
4. Expor temporariamente o backend local para o Sandbox.
5. Configurar a URL do Webhook no Asaas.
6. Receber e registrar eventos na tabela `EventoWebhook`.
7. Testar idempotência enviando o mesmo evento mais de uma vez.
8. Localizar a assinatura correspondente ao evento.
9. Salvar `asaas_subscription_id`.
10. Criar/atualizar registro em `Pagamento`.
11. Salvar `asaas_payment_id`.
12. Alterar assinatura de `PENDENTE` para `ATIVA`.
13. Preencher `data_inicio`.
14. Calcular e preencher `data_vencimento`.
15. Testar pagamento no Sandbox.
16. Validar eventos posteriores, como vencimento, cancelamento e reembolso.
17. Remover ou restringir endpoints temporários de teste antes da entrega/produção.

---

**Fim do relatório.**
