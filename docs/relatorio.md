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

### 12/10/2026 — Igor

**O que foi feito:**
- RF05 – Manter Ganhos implementado (HU14-HU17): registrar, listar, editar, excluir (exclusão física) e duplicar ganho. Como GANHO não tem FK direta para USUARIO, a posse é validada no service, conferindo se o veículo e a plataforma informados pertencem ao usuário autenticado.
- RF06 – Manter Despesas implementado (HU18-HU21): CRUD de despesas vinculado a um veículo ativo do usuário e a uma categoria válida. Criado também o módulo `categorias-despesa` (HU21), com categorias padrão (criadas automaticamente na inicialização via `onModuleInit`) e categorias personalizadas, com bloqueio de duplicidade sem diferenciar maiúsculas de minúsculas.
- `ValidationPipe` global ativado no `main.ts`. Até então as validações dos DTOs (class-validator) não estavam sendo aplicadas; após a ativação, RF01 a RF04 foram retestados.
- Correção da RN26 no RF05: criar e duplicar ganho agora recusam plataforma inativa e veículo removido (antes somente a listagem filtrava).
- Todos os cenários testados no Postman: CRUD completo, validações (400), duplicidade (409) e posse de recursos (404).

**Próximos passos:**
- Semana 4: RF07 – Gerenciar Jornada, RF08 – Registrar Quilometragem e RF09 – Calcular Indicadores Financeiros (MVP funcional).

**Dificuldades:**
- Os testes de valor negativo inicialmente falharam porque o `ValidationPipe` não estava ativado, então os decorators dos DTOs eram ignorados. Resolvido ativando o pipe globalmente no `main.ts`.

**Observações:**
- O `main.ts` precisa manter `import 'dotenv/config'`, `app.enableCors()` (necessário para o React consumir a API) e o `ValidationPipe`.
- Categorias padrão são linhas compartilhadas (`id_usuario` nulo); plataformas padrão são uma cópia por usuário (`padrao = true`).
- Exclusão de ganho e de despesa é física, pois o lançamento é o próprio dado financeiro. Já o veículo usa exclusão lógica (`ativo = false`) para preservar o histórico.
- Pendência: limitar o tamanho dos textos nos DTOs antigos com `@MaxLength`, para evitar erro 500 quando o valor excede o tamanho da coluna.

### 13/10/2026 — Nicollas Continuação do desenvolvimento mobile: Perfil, Veículos e Plataformas

**O que foi feito:**
- Dado prosseguimento ao desenvolvimento do aplicativo mobile do Route Cash.
- Finalizada a parte de manutenção do perfil do usuário no RF01.
- Implementada a tela `Meu Perfil`, utilizando os dados da rota protegida `GET /usuarios/me`.
- Implementada edição do nome do usuário através de `PATCH /usuarios/me`.
- Mantidos e-mail e tipo de usuário como campos somente leitura, conforme regras do backend.
- Ajustada a Home para atualizar automaticamente o nome exibido em `Olá, usuário!` após uma alteração no perfil.
- Implementado encerramento de conta através de `DELETE /usuarios/me`.
- Validado que o encerramento não remove fisicamente o usuário, alterando `status_conta` para `BLOQUEADO`.
- Implementada remoção do JWT após o encerramento da conta e retorno automático para a tela de login.
- Validado que usuários bloqueados não conseguem realizar novo login, recebendo a mensagem `Conta inativa ou bloqueada`.

- Iniciado e implementado o **RF03 – Manter Veículos**.
- Criada a estrutura:
  - `lib/features/vehicles/data/vehicle.dart`
  - `lib/features/vehicles/data/create_vehicle_request.dart`
  - `lib/features/vehicles/data/update_vehicle_request.dart`
  - `lib/features/vehicles/data/vehicle_repository.dart`
  - `lib/features/vehicles/providers/vehicle_providers.dart`
  - `lib/features/vehicles/presentation/vehicle_list_page.dart`
  - `lib/features/vehicles/presentation/vehicle_form_page.dart`
- Implementada listagem dos veículos do usuário autenticado.
- Implementado cadastro de veículos com:
  - marca;
  - modelo;
  - ano;
  - combustível;
  - consumo médio;
  - placa opcional.
- Implementada edição de veículos.
- Implementada definição de veículo principal.
- Implementada remoção de veículo utilizando soft delete.
- Validado que veículos removidos permanecem no banco com `ativo = false`, preservando o histórico.
- Adicionado acesso a `Meus Veículos` na Home.
- Identificada a necessidade de permitir reativação de veículos inativos para evitar novo cadastro com uma placa já existente.
- Criada inicialmente a estrutura mobile para listagem e reativação de veículos inativos.
- A alteração necessária no backend para reativação ficou pendente para alinhamento com o responsável pelo backend.
- Restaurado o botão de cadastro de veículos e o acesso a `Meus Veículos` após ajustes na tela.

- Iniciado e implementado o **RF04 – Manter Plataformas**.
- Criada a estrutura:
  - `lib/features/platforms/data/platform.dart`
  - `lib/features/platforms/data/platform_repository.dart`
  - `lib/features/platforms/providers/platform_providers.dart`
  - `lib/features/platforms/presentation/platform_list_page.dart`
  - `lib/features/platforms/presentation/platform_form_page.dart`
- Implementada listagem das plataformas vinculadas ao usuário autenticado.
- Validada exibição automática das plataformas padrão:
  - Uber;
  - 99;
  - inDrive.
- Implementado cadastro de plataformas personalizadas.
- Implementada edição somente para plataformas personalizadas.
- Plataformas padrão foram mantidas sem opção de edição, conforme regra do backend.
- Implementada ativação e inativação de plataformas.
- Validado tratamento de nomes duplicados através das regras existentes no backend.
- Adicionado acesso a `Minhas Plataformas` na Home.
- RF04 testado com sucesso no celular físico.

**Próximos passos:**
- Alinhar com o responsável pelo backend a implementação das rotas para listar e reativar veículos inativos.
- Finalizar a funcionalidade de reativação de veículos após os ajustes no backend.
- Iniciar o **RF05 – Registrar Ganhos**.
- Implementar listagem e cadastro de ganhos vinculando:
  - veículo;
  - plataforma;
  - data;
  - valor.
- Implementar posteriormente edição, exclusão e duplicação de ganhos.
- Utilizar somente veículos ativos e plataformas ativas nos novos lançamentos.

**Dificuldades:**
- O `adb reverse` precisou ser configurado novamente para restabelecer a comunicação entre o celular físico e o backend.
- Durante alguns ajustes, botões da Home e da tela de veículos foram removidos acidentalmente ao substituir arquivos completos, sendo posteriormente restaurados.
- A tentativa de acessar veículos inativos gerou `Internal Server Error` no backend.
- Foi identificado que a rota `/veiculos/inativos` estava sendo interpretada como `/veiculos/:id`, fazendo o Prisma tentar converter `inativos` para UUID.
- A correção definitiva dessa rota foi adiada para alinhamento com o integrante responsável pelo backend.
- Foi necessário ajustar a atualização da Home após editar o nome do usuário, pois inicialmente o novo nome só aparecia após sair e realizar login novamente.

**Observações:**
- O fluxo de gerenciamento de usuário está funcionando com cadastro, login, consulta, edição, encerramento e bloqueio de acesso.
- O RF03 está funcional para cadastro, listagem, edição, definição de principal e soft delete de veículos.
- A reativação de veículos inativos depende apenas do ajuste pendente no backend.
- O RF04 está funcional para plataformas padrão e personalizadas.
- Todas as operações protegidas continuam utilizando o JWT armazenado no `FlutterSecureStorage` e enviado automaticamente pelo Dio.
- O aplicativo foi testado durante o desenvolvimento em celular Android físico conectado via USB.

### 16/10/2026 — Nicollas Pilatti Avanços no mobile até RF06 e nova interface

**O que foi feito:**
- Retomado o desenvolvimento mobile do Route Cash a partir da RF05.
- Finalizada a **RF05 – Registrar Ganhos**.
- Implementadas as funcionalidades de:
  - cadastrar ganho;
  - listar ganhos;
  - editar ganho;
  - excluir ganho;
  - duplicar ganho.
- Implementada duplicação de ganho permitindo manter a data original ou selecionar uma nova data.
- Integrado o cadastro de ganhos com veículos ativos e plataformas ativas.
- Validado o funcionamento da RF05 no celular físico.

- Implementada a **RF06 – Registrar Despesas**.
- Implementadas as funcionalidades de:
  - cadastrar despesa;
  - listar despesas;
  - editar despesa;
  - excluir despesa.
- Integrado o cadastro de despesas com veículos cadastrados.
- Implementado carregamento das categorias padrão de despesas.
- Implementada criação de categorias personalizadas diretamente pelo aplicativo.
- Validado o funcionamento completo da RF06.

- Corrigido problema de ambiente relacionado ao Docker Desktop.
- Identificado erro de conexão do Prisma com o PostgreSQL na porta `5454`.
- Identificado que o Docker Desktop não iniciava devido ao WSL desatualizado.
- Atualizado o WSL e reiniciado o ambiente Docker.
- PostgreSQL voltou a funcionar normalmente e o backend recuperou a conexão com o banco.

- Analisada a implementação da **RF07 – Gerenciar Jornada**.
- Identificado erro na lógica responsável por impedir múltiplas jornadas abertas.
- Identificado erro na interpolação da mensagem de validação de horário futuro.
- Identificada ausência da quilometragem na implementação atual da jornada.
- A implementação mobile da RF07 foi adiada até a finalização da funcionalidade no backend.

- Iniciada a reformulação visual do aplicativo mobile.
- Criado um tema global utilizando Material 3.
- Definida uma nova identidade visual utilizando verde como cor principal.
- Melhorado o contraste dos textos e elementos secundários.
- Criada diferenciação visual entre ganhos e despesas.
- Adicionado suporte a tema claro e escuro.
- Configurado o aplicativo para acompanhar automaticamente o tema definido no Android.

- Reformulada a tela inicial do Route Cash.
- A Home passou de uma tela de navegação simples para um **dashboard financeiro**.
- Implementado cabeçalho compacto com nome do usuário e data atual.
- Implementado painel financeiro utilizando dados reais cadastrados no sistema.
- O painel apresenta:
  - lucro líquido;
  - total de ganhos;
  - total de despesas.
- Implementados atalhos rápidos para registrar ganho e registrar despesa.
- Perfil, veículos, plataformas e logout foram reorganizados em um menu secundário.

- Implementado filtro de período no painel financeiro.
- Adicionadas as opções:
  - Dia;
  - Semana;
  - Mês;
  - Ano.
- Mantido apenas um painel, alterando os dados apresentados conforme o filtro selecionado.
- Implementada navegação entre períodos anteriores e posteriores.
- Implementado seletor de data através de calendário.
- Implementado botão para retornar rapidamente ao período atual.
- Ganhos, despesas e lucro líquido passaram a ser recalculados de acordo com o período selecionado.

- Refinada a seção **Atividades do período**.
- As atividades passaram a respeitar o mesmo período selecionado no painel financeiro.
- Implementados filtros:
  - Todos;
  - Ganhos;
  - Despesas.
- Adicionada contagem dos lançamentos em cada filtro.
- Limitada inicialmente a exibição a cinco lançamentos.
- Implementada opção `Mostrar todas` quando houver mais registros.
- Ajustado tratamento das datas para evitar alteração do dia causada pelo fuso horário.
- Ajustada a organização da lista para exibir ganhos e despesas de forma mais equilibrada quando possuem a mesma data.

**Arquivos criados:**
- `lib/features/earnings/data/earning.dart`
- `lib/features/earnings/data/create_earning_request.dart`
- `lib/features/earnings/data/update_earning_request.dart`
- `lib/features/earnings/data/earning_repository.dart`
- `lib/features/earnings/providers/earning_providers.dart`
- `lib/features/earnings/presentation/earning_list_page.dart`
- `lib/features/earnings/presentation/earning_form_page.dart`

- `lib/features/expenses/data/expense.dart`
- `lib/features/expenses/data/expense_category.dart`
- `lib/features/expenses/data/create_expense_request.dart`
- `lib/features/expenses/data/update_expense_request.dart`
- `lib/features/expenses/data/expense_repository.dart`
- `lib/features/expenses/data/expense_category_repository.dart`
- `lib/features/expenses/providers/expense_providers.dart`
- `lib/features/expenses/presentation/expense_list_page.dart`
- `lib/features/expenses/presentation/expense_form_page.dart`

- `lib/core/theme/app_theme.dart`

**Arquivos modificados:**
- `lib/main.dart`
  - Aplicação do novo tema global.
  - Suporte a tema claro e escuro.
  - Configuração do `ThemeMode.system`.

- `lib/features/home/presentation/home_page.dart`
  - Reformulação completa da tela inicial.
  - Dashboard financeiro.
  - Filtros Dia, Semana, Mês e Ano.
  - Seletor de período.
  - Cálculo de ganhos, despesas e lucro.
  - Atalhos rápidos.
  - Atividades do período.
  - Filtros de atividades.
  - Menu de perfil, veículos, plataformas e logout.

- `lib/features/earnings/data/earning_repository.dart`
  - Adicionada integração para duplicação de ganhos.

- `lib/features/earnings/presentation/earning_list_page.dart`
  - Adicionada opção de duplicar ganho.
  - Adicionado seletor para manter ou alterar a data da duplicação.

**Próximos passos:**
- Continuar a padronização visual das demais telas do aplicativo.
- Aplicar o novo padrão visual às telas de:
  - ganhos;
  - despesas;
  - veículos;
  - plataformas;
  - perfil;
  - login;
  - cadastro.
- Avaliar posteriormente a criação de uma barra de navegação inferior.
- Retomar a RF07 após a finalização da implementação de jornadas no backend.
- Integrar quilometragem e duração da jornada.
- Adicionar posteriormente os indicadores:
  - ganho por hora;
  - ganho por quilômetro;
  - custo por quilômetro;
  - quilômetros rodados;
  - tempo conectado.
- Evoluir posteriormente o dashboard com gráficos e metas.

**Dificuldades:**
- O Prisma perdeu temporariamente a conexão com o PostgreSQL devido ao Docker Desktop não iniciar.
- Foi necessário atualizar o WSL para recuperar o funcionamento do Docker.
- Foram identificados erros na implementação inicial do backend de jornadas, impedindo o avanço da RF07.
- A primeira implementação das atividades do dashboard apresentava principalmente ganhos quando vários lançamentos possuíam a mesma data.
- Foi necessário ajustar a lógica de filtragem e organização dos lançamentos.
- Foi identificado risco de alteração do dia por causa da conversão de fuso horário, sendo necessário ajustar o tratamento das datas.

**Observações:**
- RF05 concluída e funcional.
- RF06 concluída e funcional.
- RF07 permanece pendente até a finalização do backend.
- Ganhos e despesas já alimentam diretamente o dashboard da tela inicial.
- Os filtros de Dia, Semana, Mês e Ano utilizam os dados reais cadastrados.
- A tela inicial já está preparada para receber futuramente indicadores de jornada, desempenho e metas.
- O aplicativo continua sendo testado em celular Android físico integrado ao backend NestJS e PostgreSQL.



### 17/10/2026 — Igor

**O que foi feito:**
- RF07 – Gerenciar Jornada implementado (HU22-HU24): iniciar jornada vinculada a um veículo ativo do usuário, com bloqueio de mais de uma jornada em aberto (409); finalizar jornada com cálculo automático da duração (`duracao_minutos`, calculada a partir de início e fim, sem ser gravada no banco); editar horários validando o período (fim posterior ao início e sem horários no futuro). Criada também a rota `GET /jornadas/em-andamento`, útil para o mobile.
- RF08 – Registrar Quilometragem implementado (HU25-HU27): no modelo lógico, a quilometragem é o campo `km_rodados` da jornada, então o registro já nasce vinculado a um veículo e a uma data. Registrar, editar e remover (remover zera o km e preserva a jornada), com validação de km maior que zero e bloqueio de registro duplicado na mesma jornada (409).
- RF09 – Calcular Indicadores Financeiros implementado (HU28-HU30): `GET /indicadores` retorna faturamento, despesas, lucro líquido, horas trabalhadas, km rodados, ganho por hora, ganho por km e custo por km, com filtro por período (padrão: dia atual). Sem horas ou km no período, os indicadores correspondentes retornam `null`, evitando divisão por zero. Como o cálculo é feito sob demanda, sem cache, qualquer edição ou exclusão aparece no cálculo seguinte (recálculo automático da HU29).
- Melhorias no módulo de veículos a partir de um problema encontrado no mobile: `GET /veiculos/inativos`, `PATCH /veiculos/:id/reativar`, aviso específico quando a placa cadastrada pertence a um veículo removido do próprio usuário (409 com `id_veiculo_inativo`), bloqueio de edição e de definição como principal em veículo inativo.
- Todos os cenários testados no Postman: fluxo completo de jornada, quilometragem, indicadores com e sem lançamentos e validações de período (400).

**Próximos passos:**
- Semana 5: RF10 – Visualizar Indicadores Financeiros (séries diárias e médias para os gráficos) e RF11 – Sincronizar Dados.
- Iniciar o front-end React: login e dashboard com gráficos (Recharts).

**Dificuldades:**
- O mobile identificou que um veículo removido não podia ser recadastrado (placa única) nem reativado. A tentativa de acessar `/veiculos/inativos` retornava erro 500, porque a rota inexistente caía em `/veiculos/:id` e o Prisma tentava converter "inativos" em UUID. Resolvido criando as rotas de inativos e reativar, declaradas antes de `:id`.
- Divergência entre o código entregue e a leitura feita pela IA do mobile sobre o `iniciar()` da jornada. O código original estava correto; ficou combinado validar pelo Postman e passar código entre chats em bloco de código ou arquivo, pois a crase de template string se perde no texto.

**Observações:**
- Rotas fixas (como `inativos` e `em-andamento`) precisam ser declaradas antes de `:id` nos controllers.
- Ganho por hora = lucro líquido ÷ horas (somente jornadas finalizadas). Ganho por km e custo por km usam o km das jornadas do período. O período usa a data local do servidor.
- Pendências opcionais: limitar o tamanho dos textos nos DTOs antigos com `@MaxLength` e criar índice único parcial para impedir duas jornadas abertas por disputa entre requisições.

### 17/10/2026 — Nicollas Pilatti-Mudanças visuais e ajustes nos veiculos

**O que foi feito:**
- Retomada a pendência da **RF03 – Manter Veículos**, principalmente relacionada a veículos inativos e reutilização de placas.
- Revisado o backend atualizado de veículos.
- Confirmado o funcionamento das rotas:
  - `GET /veiculos/inativos`;
  - `PATCH /veiculos/:id/reativar`.
- Corrigido no backend o problema anterior em que a rota `inativos` poderia ser interpretada como um UUID.
- Mantido o uso de `ParseUUIDPipe` nas rotas que recebem identificador de veículo.
- Mantida a remoção lógica do veículo através do campo `ativo`, preservando ganhos, despesas e jornadas históricas.
- Implementada lógica para identificar tentativa de cadastrar uma placa pertencente a um veículo inativo.
- Backend passou a retornar o `id_veiculo_inativo` quando a placa já pertence a um veículo removido do próprio usuário.
- Preparado no mobile o fluxo para oferecer a opção de **reativar o veículo existente**, evitando registros duplicados.
- Ajustada a tela de veículos inativos para permitir reativação.
- Ajustado o fluxo de cadastro para tratar conflitos de placa.
- Adicionada normalização da placa no mobile:
  - conversão para letras maiúsculas;
  - remoção de caracteres desnecessários;
  - validação do formato da placa brasileira.

**Melhorias visuais nas plataformas:**
- Iniciada melhoria visual da identificação das plataformas utilizadas nos ganhos.
- Criada estrutura de assets específica para logos de aplicativos.
- Adicionados arquivos de imagem para:
  - Uber;
  - 99;
  - inDrive.
- Criado componente reutilizável `PlatformIcon`.
- O componente identifica automaticamente o nome da plataforma e carrega o logo correspondente.
- Implementado fallback com ícone genérico para plataformas personalizadas, como `Particular`.
- Aplicado o novo componente visual nas telas de:
  - cadastro e edição de ganhos;
  - listagem de ganhos;
  - listagem de plataformas;
  - atividades recentes da Home.
- Na Home, ganhos passaram a poder utilizar o logo da plataforma no lugar da seta genérica.
- Na listagem de ganhos, o logo passou a identificar visualmente a plataforma do lançamento.
- Na tela de plataformas, os logos passaram a aparecer juntamente com o nome e status da plataforma.

**Correções realizadas:**
- Identificado que os logos inicialmente apareciam como quadrados com `X`, indicando falha no carregamento dos assets.
- Verificada a estrutura correta dos arquivos:
  - `mobile/assets/platforms/uber.png`;
  - `mobile/assets/platforms/99.png`;
  - `mobile/assets/platforms/indrive.png`.
- Identificado erro de indentação no `pubspec.yaml`.
- O bloco `assets:` estava fora do bloco `flutter:`, fazendo com que o Flutter não registrasse as imagens.
- Corrigida a configuração para:
yaml
flutter:
  uses-material-design: true

  assets:
    - assets/platforms/

### 20/10/2026 — Nicollas Pilatti- RF07 até RF10 mobile 
**O que foi feito:**
- Revisado o backend de **Jornadas** desenvolvido pelo colega, validando as rotas para iniciar, listar, consultar, finalizar e editar jornadas.
- Confirmado o controle de apenas uma jornada em andamento por usuário.
- Validado o cálculo de duração da jornada realizado pelo backend.
- Revisado o backend de **Quilometragem**, confirmando que o valor de `km_rodados` pertence à própria `JORNADA`, sem criação de uma entidade separada.
- Validado o fluxo de registrar, editar e remover quilometragem de uma jornada.
- Revisado o backend de **Indicadores Financeiros**, incluindo faturamento, despesas, lucro líquido, horas trabalhadas, quilômetros rodados, ganho por hora, ganho por km e custo por km.
- Criada a estrutura da funcionalidade de **Jornadas no aplicativo mobile**.
- Implementado o model de Jornada e objetos utilizados nas requisições.
- Implementado o repositório responsável pela comunicação com os endpoints de Jornada e Quilometragem.
- Implementada a tela principal de Jornadas.
- Implementada seleção do veículo para início da jornada.
- Implementado início de jornada utilizando o backend.
- Implementado cronômetro local em tempo real para jornadas em andamento, sem realizar requisições ao servidor a cada segundo.
- Implementada detecção automática de uma jornada em andamento ao abrir a tela.
- Implementada finalização da jornada.
- Adicionado campo opcional para informar os quilômetros rodados ao finalizar a jornada.
- Tratado o caso em que a jornada é finalizada com sucesso, mas ocorre erro ao registrar a quilometragem.
- Implementado histórico de jornadas com veículo, data, horários, duração e quilometragem.
- Criada tela para **edição de jornadas finalizadas**.
- Implementada alteração de data e horário inicial e final.
- Implementado recálculo da duração após alteração dos horários.
- Implementado cadastro posterior de quilometragem em jornadas que ainda não possuem KM.
- Implementada edição de quilometragem existente.
- Implementada remoção da quilometragem sem excluir a jornada.
- Adicionada opção **Editar jornada** diretamente no histórico.
- Jornada foi integrada à **Home** de forma explícita, através de um card próprio.
- Corrigido problema em que o arquivo atualizado da Home não havia sido substituído no diretório correto do projeto.
- Card de Jornada da Home passou a ser **dinâmico**.
- Quando não existe jornada ativa, a Home informa que não há jornada em andamento.
- Quando existe jornada ativa, a Home apresenta veículo, horário de início e cronômetro.
- Criada a estrutura mobile para **Indicadores Financeiros**.
- Implementados model, repository e provider dos indicadores.
- Integrado `GET /indicadores` à Home.
- Os filtros **Dia, Semana, Mês e Ano** passaram a controlar também o período enviado ao backend para cálculo dos indicadores.
- Adicionado card de indicadores na Home com:
  - tempo trabalhado;
  - quilômetros rodados;
  - ganho por hora;
  - ganho por km;
  - custo por km.
- O resumo financeiro da Home passou a utilizar os valores calculados pelo backend como fonte principal.
- Testados os indicadores por diferentes períodos.
- Confirmado que semanas anteriores com ganhos, mas sem jornadas registradas, não possuem horas/KM suficientes para calcular os indicadores.
- Confirmado que a semana atual apresenta corretamente as horas das jornadas cadastradas.
- Jornada, Quilometragem e Indicadores foram testados no dispositivo físico e estão funcionando.

**Pastas criadas:**
```text
mobile/lib/features/journeys/
mobile/lib/features/journeys/data/
mobile/lib/features/journeys/providers/
mobile/lib/features/journeys/presentation/

mobile/lib/features/indicators/
mobile/lib/features/indicators/data/
mobile/lib/features/indicators/providers/
```

**Arquivos criados:**
```text
mobile/lib/features/journeys/data/journey.dart
mobile/lib/features/journeys/data/start_journey_request.dart
mobile/lib/features/journeys/data/update_journey_request.dart
mobile/lib/features/journeys/data/journey_repository.dart
mobile/lib/features/journeys/providers/journey_providers.dart
mobile/lib/features/journeys/presentation/journey_page.dart
mobile/lib/features/journeys/presentation/finish_journey_page.dart
mobile/lib/features/journeys/presentation/journey_edit_page.dart

mobile/lib/features/indicators/data/financial_indicators.dart
mobile/lib/features/indicators/data/indicators_repository.dart
mobile/lib/features/indicators/providers/indicator_providers.dart
```

**Arquivos modificados:**
```text
mobile/lib/features/home/presentation/home_page.dart
```

**Próximos passos:**
- Melhorar a apresentação dos indicadores quando não houver horas ou quilômetros suficientes, exibindo mensagens como **“Sem horas registradas”** e **“Sem KM registrados”** em vez de valores zerados.
- Realizar uma revisão final de Jornada, Quilometragem e Indicadores antes do commit.
- Corrigir avisos restantes do `flutter analyze`.
- Continuar para os próximos requisitos do Route Cash.
- Implementar posteriormente o campo opcional de **observação** nos registros de ganhos e despesas.

**Dificuldades:**
- O card de Jornada inicialmente não apareceu na Home porque o arquivo `home_page.dart` atualizado não havia sido substituído no local correto do projeto.
- Foi necessário verificar pelo PowerShell se o código do card realmente estava presente no arquivo utilizado pelo Flutter.
- Os indicadores de períodos antigos inicialmente pareceram incorretos, porém foi identificado que existiam ganhos e despesas nesses períodos, mas não jornadas com horas e quilometragem registradas.
- Permaneceram alguns avisos antigos do `flutter analyze`, sem impedir a compilação ou execução do aplicativo.

**Observações:**
- A implementação do backend de Jornada, Quilometragem e Indicadores foi realizada pelo colega e nesta etapa foi revisada e integrada ao aplicativo mobile.
- A duração da jornada não é armazenada separadamente; é calculada pelo backend utilizando os horários de início e fim.
- A quilometragem continua pertencendo à entidade `JORNADA`, através do campo `km_rodados`.
- O cronômetro exibido no aplicativo é atualizado localmente e não gera requisições contínuas ao backend.
- Os cálculos de ganho por hora e ganho por km utilizam o **lucro líquido** do período.
- Caso não existam horas ou quilômetros no período selecionado, o backend não realiza divisão por zero e retorna o indicador como `null`.
- O fluxo **iniciar jornada → acompanhar → finalizar → registrar KM → editar jornada/KM → visualizar indicadores** está funcional no mobile.

    

### 22/10/2026 — Igor

**O que foi feito:**
- RF10 – Visualizar Indicadores Financeiros (backend, HU31-HU32): rota `GET /indicadores/serie`, com a série diária (faturamento, despesas, lucro líquido e lucro acumulado), totais do período e médias diárias, para alimentar os gráficos. Usa o mesmo filtro de período do RF09, preenche com zero os dias sem lançamento e limita o período a 366 dias. A soma da série bate com os totais de `GET /indicadores`.
- RF11 – Sincronizar Dados (backend, HU33-HU34): novo módulo `sincronizacao`. `POST /sincronizacao/enviar` recebe em lote os ganhos, despesas, jornadas e exclusões do app e devolve um resultado por item (`ok`, `ignorado` ou `erro`, com código e motivo). Um item inválido não trava o lote, o reenvio do mesmo registro é idempotente (UUID gerado no app), o conflito de edição é resolvido pela alteração mais recente e as exclusões são processadas por último. `GET /sincronizacao/baixar` devolve o retrato completo dos dados do usuário para o app se atualizar, inclusive com o que foi alterado ou excluído na web.
- Contrato de sincronização alinhado com o Nicollas e documentado em `contrato-sincronizacao.md`: UUID gerado no app para todo lançamento, lançamentos sempre gravados por `/sincronizacao/enviar`, horários em UTC com sufixo Z, lotes de até 50 itens por lista e cadastros (veículo, plataforma, categoria) somente online, com cache no app.
- Melhorias definidas pela dupla após a Semana 4: lançamento manual de jornada (`POST /jornadas/manual`), exclusão de jornada (`DELETE /jornadas/:id`, que remove também a quilometragem registrada nela) e campo opcional de observação em ganhos e despesas (migration `add_observacao_ganho_despesa`). Nova regra: jornadas do mesmo usuário não podem se sobrepor (409), valendo para iniciar, editar horários e lançar jornada manual.
- Backend das funcionalidades RF01 a RF11 (MVP) concluído e testado no Postman, incluindo os cenários de erro (validações, duplicidade, sobreposição, posse de recursos e idempotência da sincronização).

**Próximos passos:**
- Iniciar o front-end React (Vite + TypeScript): base do projeto, login e cadastro, rotas protegidas e dashboard (RF10) com Recharts, reaproveitando a identidade visual (cores) do app mobile.
- Semana 6: RF12 – Visualizar Planos, RF13 – Gerenciar Assinatura e RF14 – Consultar Pagamentos.
- Acompanhar a implementação da sincronização no mobile (Nicollas) e ajustar o backend caso a integração aponte divergências do contrato.

**Dificuldades:**
- Ao adicionar o campo `observacao`, o `prisma migrate dev` gerou uma migration vazia e depois pediu o nome de uma nova migration. A causa era o `schema.prisma` do projeto estar sem o campo, então o Prisma não via diferença entre o schema e o banco. Resolvido incluindo o campo no schema; as colunas foram criadas pela migration já aplicada.
- O contrato de sincronização precisou de ajustes em relação ao desenho inicial: o id gerado no app obriga a gravar os lançamentos pelo endpoint de sincronização, o formato de horário exige fuso explícito e a exclusão de jornada passou a existir no backend.

**Observações:**
- A sincronização envia o estado completo de cada registro (criar e editar são a mesma operação). Itens com `ok` ou `ignorado` saem da fila do app; `erro` com `ERRO_INTERNO` é reenviado; os demais erros ficam locais com o motivo para o usuário corrigir ou descartar.
- O prazo de 5 minutos após a volta da conexão (RNF11) depende do app disparar o envio ao detectar a conexão (`connectivity_plus`).
- Decidido não implementar por ora a exibição de planos na tela de login para quem ainda não tem cadastro. Pode ser feita no futuro com uma rota pública de planos.
- Pendências: limitar o tamanho dos textos nos DTOs antigos com `@MaxLength`; índice único parcial para impedir duas jornadas em aberto por disputa entre requisições (opcional); atualizar o diagrama do modelo lógico e as histórias de usuário no DVP final para refletir a observação, o lançamento manual e a exclusão de jornada.



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
