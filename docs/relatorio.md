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
