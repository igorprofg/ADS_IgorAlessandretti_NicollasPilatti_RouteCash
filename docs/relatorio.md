# Relatório de Desenvolvimento — RouteCash

Esse documnto tem o objetivo de registrar o que esta sendo feito/desenvolvido durante o projeto, a fim de lembrar
nós desenvolvedores as: decisões, dificuldades e objetivos que foram e ainda serão feitos. 

## Objetivo do projeto
Sistema híbrido (mobile + web) para motoristas de aplicativo gerenciarem suas finanças: ganhos, despesas, jornada, quilometragem e indicadores financeiros (lucro líquido, ganho/hora, ganho/km), com um módulo adicional de assinatura/planos e retaguarda administrativa.

## Como rodar o projeto (backend)

```bash
cd backend

# Sobe o PostgreSQL em container
docker compose up -d

# Instala as dependências
npm install

# Aplica as migrations no banco (se ainda não aplicadas)
npx prisma migrate dev

# Sobe o servidor NestJS em modo desenvolvimento
npm run start:dev
```

PARTE MOBILE: 

```bash
# Para testar o app mobile com dados reais, a ordem no computador dele sempre deve ser:

Abrir o Docker Desktop.

Rodar o backend (cd backend -> npm run start:dev).

Rodar o app Flutter (cd mobile -> flutter run).
```

O servidor sobe em `http://localhost:3000`. Pra inspecionar o banco visualmente: `npx prisma studio`.

---

obs: 

Para manter o histórico legível no GitHub, usamos um padrão simples de mensagens:

feat(backend): implementa DTO de cadastro de usuário

feat(mobile): cria tela de login e formulário

fix(mobile): ajusta validação do campo email

## Entradas

### 29/09/2026 — Igor
**O que foi feito:**
- Modelagem lógica do banco finalizada (10 entidades) após correções sugeridas pelo professor na apresentação do DVP.
- Estrutura de pastas do monorepo criada (`backend/`, `frontend/`, `mobile/`).
- Setup do backend: NestJS + Prisma + PostgreSQL (via Docker) configurado e funcionando.
- `schema.prisma` completo escrito e migration inicial aplicada com sucesso.

**Próximos passos:**
- Implementar RF01 – Manter Usuários (cadastro, edição, exclusão).
- Implementar RF02 – Gerenciar Login (autenticação JWT).

**Dificuldades:**
- Erro de autenticação do Prisma com o Docker (P1000) — causado por conflito de porta com outro PostgreSQL já rodando localmente na máquina. Resolvido mudando a porta exposta do container para `5454`.

**Observações:**
- Prisma não suporta índice único parcial (`WHERE`) direto no schema — precisa editar a migration SQL manualmente após gerar com `--create-only`.
- Commits sempre a partir da pasta raiz do repositório, nunca de dentro de `backend/`, `frontend/` ou `mobile/` isoladamente.

---
### 29/09/2026 — Nicollas
**O que foi feito:**
- Realizada a instalçaõ das dependencias necessárias para rodar a parte mobile do projeto, integrações com o banco de dados e estruturação de pastas padrões dart/flutter
**Próximos passos:**
- Implemntar RF01 no projeto mobile e teste de integração com a parte web
**Dificuldades:**
- Por ter mitas dependencias e diferentes ferramentas, algumas deram alguns erros por conta do SO, como o docker por exemplo, que foi necessario alguns ajustes para rodar ele no windows 



### 01/10/2026 — Igor
**O que foi feito:**
- Conclusão do RF01 (Manter Usuários): Implementado cadastro com validação de DTOs (`class-validator`), hash de senha (`bcrypt`), criação automática de plataformas padrão (Uber, 99, inDrive) e exclusão lógica de conta (alteração de status para BLOQUEADO).
- Conclusão do RF02 (Gerenciar Login): Implementado `AutenticacaoModule` com validação de e-mail/senha e geração de token JWT.
- Segurança aprimorada: Criação do `JwtAuthGuard` e do decorator customizado `@UsuarioAtual()`. 
- Refatoração: Substituição das rotas vulneráveis de usuário (`/:id`) pelas rotas protegidas (`/me`), garantindo que o usuário só altere seus próprios dados.

**Próximos passos:**
- Implementar o RF03 – Manter Veículos (cadastro, listagem, edição e exclusão de veículos restritos ao usuário logado).

**Dificuldades:**
- Erro no import de módulos causado por *case sensitivity* no nome da classe TypeScript (`JwtStrategy` com letra maiúscula/minúscula). Resolvido padronizando para PascalCase.
- Erro `JwtStrategy requires a secret or key` na inicialização do NestJS. A causa foi um erro de digitação interno da biblioteca `passport-jwt` (`secretOrkey` com "k" minúsculo no lugar de `secretOrKey`), o que fazia a variável de ambiente ser ignorada em tempo de execução.

**Observações:**
- Como foram instaladas novas bibliotecas (JWT, Passport, Bcrypt), o desenvolvedor Mobile (Nicolas) obrigatoriamente precisa rodar `npm install` na pasta `backend` após o `git pull`.
- É obrigatório adicionar as chaves `JWT_SECRET` e `JWT_EXPIRES_IN` no arquivo `.env` para que o servidor suba corretamente.

---

### 04/10/2026 — Nicollas Início do desenvolvimento mobile e RF01

**O que foi feito:**
- Configurado e validado o ambiente Flutter para desenvolvimento Android.
- Aplicativo executado com sucesso em celular físico via USB.
- Criada a estrutura inicial do projeto mobile para organização por funcionalidades.
- Criados os arquivos:
  - `lib/core/config/app_config.dart`
  - `lib/core/network/dio_client.dart`
  - `lib/features/users/data/create_user_request.dart`
  - `lib/features/users/data/user_repository.dart`
  - `lib/features/users/providers/user_providers.dart`
  - `lib/features/users/presentation/register_page.dart`
- Configurado o Dio para comunicação do aplicativo com a API NestJS.
- Configurado Riverpod no aplicativo.
- Iniciado o desenvolvimento do **RF01 – Manter Usuários**, com foco na **HU03 – Criar Usuário**.
- Implementada tela de cadastro com nome, e-mail, senha, confirmação de senha e aceite dos Termos de Uso.
- Implementadas validações de campos obrigatórios, e-mail, senha mínima de 6 caracteres, confirmação de senha e aceite dos termos.
- Ajustada a integração para o endpoint `POST /usuarios`.
- Ajustado o JSON enviado pelo Flutter conforme o `CriarUsuarioDto` do backend.
- Configurado acesso do celular ao backend utilizando `adb reverse`.
- Adicionado `android:usesCleartextTraffic="true"` no `AndroidManifest.xml` para permitir comunicação HTTP durante o desenvolvimento.
- Corrigido o teste padrão do Flutter em `test/widget_test.dart`.
- Executados `flutter analyze` e `flutter test` com sucesso.
- Corrigida dependência `dotenv` ausente no backend.
- Validado cadastro real de usuários pelo aplicativo no PostgreSQL através do Prisma Studio.
- Confirmada a criação automática das plataformas padrão **Uber, 99 e inDrive** para novos usuários.

**Próximos passos:**
- Corrigir a tela preta apresentada após a criação bem-sucedida da conta.
- Direcionar o usuário para a tela de login após concluir o cadastro.
- Finalizar as demais operações do RF01: consultar, editar e excluir perfil.
- Iniciar o RF02 – Gerenciar Login e autenticação JWT.

**Dificuldades:**
- Configuração inicial das ferramentas Android sem depender do Android Studio para desenvolvimento.
- Backend não iniciava devido à ausência da dependência `dotenv`.
- Prisma apresentou erro `P1001` porque o PostgreSQL no Docker não estava iniciado.
- Comunicação inicial entre celular e API exigiu configuração de `adb reverse` e liberação de HTTP no Android.
- Tela ficou preta após o cadastro devido ao fluxo de navegação do Flutter ainda não estar finalizado.

**Observações:**
- O fluxo de cadastro já está funcional de ponta a ponta: **Flutter → NestJS → Prisma → PostgreSQL**.
- As senhas são armazenadas no banco em formato de hash.
- A criação automática das três plataformas padrão foi confirmada no banco.


### 06/10/2026 — Igor

**O que foi feito:**
- RF03 – Manter Veículos implementado (HU06-HU09): cadastrar, editar, excluir (soft delete via campo `ativo`, preservando histórico de ganhos/despesas) e definir veículo principal.
- RF04 – Manter Plataformas implementado (HU10-HU13): listar plataformas do usuário (padrão + personalizadas), cadastrar plataforma personalizada, bloquear edição de plataformas padrão, alternar status ativa/inativa.
- Testes completos no Postman para os dois módulos, incluindo cenários de erro (placa duplicada, nome de plataforma duplicado, tentativa de editar plataforma padrão).
- Corrigido o tratamento de erro de placa duplicada em Veículo, que inicialmente retornava 500 (erro não tratado do Prisma) e passou a retornar 409 Conflict com mensagem amigável.

**Próximos passos:**
- Implementar RF05 – Manter Ganhos (HU14-HU17).
- Implementar RF06 – Manter Despesas (HU18-HU21).

**Dificuldades:**
- Nenhuma dificuldade técnica relevante nesta semana — os módulos seguiram o mesmo padrão já validado em RF01/RF02.

**Observações:**
- GANHO e DESPESA (próximos módulos) não têm FK direta pra USUARIO — a posse precisa ser validada manualmente no service, via o veículo (e plataforma/categoria) vinculado.

**Feat:**

- RF03 - Manter Veiculos (HU06-HU09):
  * CRUD completo, soft delete (campo ativo) e definicao de veiculo principal via transaction.
  * Tratamento de erro 409 Conflict para placas duplicadas.

- RF04 - Manter Plataformas (HU10-HU13):
  * Listagem de plataformas padrao e customizadas.
  * Bloqueio de edicao das plataformas padrao (403 Forbidden) e alternancia de status.

- Planejamento proxima entrega (Prazo: 12/10/2026 as 23:59):
  * Inicio da implementacao do RF05 (Ganhos) e RF06 (Despesas)."

  ### 06/10/2026 — Nicollas Implementação do Login, JWT e Controle de Sessão

**O que foi feito:**
- Corrigido o fluxo após a criação de usuário, eliminando a tela preta apresentada depois do cadastro.
- Ajustada a navegação para que a aplicação inicie pela tela de login e permita acessar a tela de criação de conta.
- Após o cadastro bem-sucedido, o usuário passou a retornar corretamente para a tela de login.
- Criada a estrutura inicial da autenticação no mobile.
- Criados os arquivos:
  - `lib/features/auth/data/login_request.dart`
  - `lib/features/auth/data/login_response.dart`
  - `lib/features/auth/data/auth_repository.dart`
  - `lib/features/auth/providers/auth_providers.dart`
  - `lib/features/auth/presentation/login_page.dart`
  - `lib/features/auth/presentation/auth_gate.dart`
  - `lib/core/storage/secure_storage.dart`
  - `lib/features/home/presentation/home_page.dart`
- Modificados os arquivos:
  - `lib/main.dart`
  - `lib/core/network/dio_client.dart`
  - `lib/features/users/data/user_repository.dart`
  - `lib/features/users/presentation/register_page.dart`
  - `test/widget_test.dart`
- Implementado login utilizando o endpoint `POST /autenticacao/login`.
- Integrado o formulário de login com e-mail e senha aos usuários já cadastrados no PostgreSQL.
- Implementado tratamento de credenciais inválidas e contas sem acesso válido.
- Implementado recebimento do JWT retornado pelo backend após autenticação.
- Configurado `FlutterSecureStorage` para armazenamento seguro do token JWT.
- Configurado o Dio para adicionar automaticamente o token JWT no cabeçalho:
  - `Authorization: Bearer <token>`
- Integrada e testada a rota protegida `GET /usuarios/me`.
- Validado que o usuário autenticado consegue consultar apenas os dados do próprio perfil.
- Criada uma tela inicial provisória (`HomePage`) exibindo os dados do usuário autenticado.
- Implementado `AuthGate` para verificar a existência de uma sessão salva ao iniciar o aplicativo.
- Implementado botão de logout.
- No logout, o JWT armazenado é removido e o usuário retorna para a tela de login.
- Testado com sucesso o fluxo de login, autenticação, consulta de perfil e logout no celular físico.

**Próximos passos:**
- Validar completamente a manutenção da sessão ao fechar e abrir novamente o aplicativo.
- Continuar o RF01 – Manter Usuários.
- Implementar edição dos dados do próprio perfil utilizando `PATCH /usuarios/me`.
- Implementar exclusão da própria conta utilizando `DELETE /usuarios/me`.
- Criar uma tela definitiva de perfil do usuário.
- Após finalizar o gerenciamento de usuários e autenticação, iniciar o desenvolvimento do RF03 – Manter Veículos.

**Dificuldades:**
- Tela preta após o cadastro devido ao fluxo de navegação enquanto a tela de cadastro ainda era a rota inicial do aplicativo.
- Erro do Riverpod após alteração de `StatefulWidget` para `ConsumerStatefulWidget`, solucionado com reinicialização completa do aplicativo.
- Erro de construtor da `HomePage` causado por alterações estruturais aplicadas durante o Hot Reload, solucionado com `flutter clean` e nova execução do aplicativo.
- Ajustes necessários no código após a mudança da Home para buscar os dados diretamente através da rota protegida `/usuarios/me`.
- Correção de warnings de imports e variáveis não utilizadas durante a implementação.

**Observações:**
- O cadastro de usuários continua funcionando normalmente.
- O login já utiliza usuários reais cadastrados no PostgreSQL.
- As senhas continuam sendo validadas pelo backend através do `bcrypt`.
- O JWT é armazenado no dispositivo através do `FlutterSecureStorage`.
- As requisições protegidas já enviam automaticamente o JWT através do Dio.
- O endpoint `GET /usuarios/me` foi testado com sucesso após o login.
- O botão de sair remove corretamente o token e retorna o usuário para a tela de login.
- O fluxo atual já permite: **Cadastrar usuário → Fazer login → Autenticar com JWT → Consultar perfil → Sair do sistema**.

<!-- Próxima entrada: copiar o modelo abaixo -->
<!--
### DD/MM/AAAA — Nome
**O que foi feito:**
-

**Próximos passos:**
-

**Dificuldades:**
-

**Observações:**
-
-->
