# Relatório de Desenvolvimento — RouteCash (Frontend)

Esse documento tem o objetivo de registrar o que está sendo feito/desenvolvido durante o projeto, a fim de lembrar os desenvolvedores das decisões, dificuldades e objetivos que foram e ainda serão realizados.

## Objetivo do projeto

Sistema híbrido (mobile + web) para motoristas de aplicativo gerenciarem suas finanças: ganhos, despesas, jornada, quilometragem e indicadores financeiros (lucro líquido, ganho/hora, ganho/km), com um módulo adicional de assinatura/planos e retaguarda administrativa.

## Como rodar o projeto (frontend)

**Pré-requisitos:**
- Node.js e npm instalados.
- Backend do RouteCash configurado e em execução para testar as funcionalidades que dependem da API.
- Banco de dados configurado conforme as instruções do backend.

**1. Acessar a pasta do frontend**

Na raiz do repositório:

```bash
cd front-end
```

**2. Instalar as dependências**

```bash
npm install
```

**3. Iniciar o servidor de desenvolvimento**

```bash
npm run dev
```

O Vite exibirá no terminal o endereço local da aplicação. Considerando a configuração padrão:

- **Login:** http://localhost:5173/login
- **Cadastro:** http://localhost:5173/cadastro
- **Dashboard:** http://localhost:5173/dashboard

Observação: a porta padrão do Vite é 5173, mas pode mudar caso esteja ocupada ou tenha sido configurada de outra forma.

O Dashboard exige autenticação. Caso o usuário não esteja autenticado, deverá ser redirecionado para o Login.

**4. Gerar a versão de produção para validar a compilação**

```bash
npm run build
```

## Entradas

### 04/11/2026 — Igor

**O que foi feito:**

- Implementação da estrutura inicial de autenticação do frontend, incluindo integração com o backend.
- Implementação do formulário de Login e da tela de Cadastro.
- Criação do contexto de autenticação (`AutenticacaoContexto.tsx`), responsável pelo estado de autenticação do usuário.
- Implementação dos serviços de autenticação e comunicação com a API, utilizando Axios.
- Configuração do envio do token JWT nas requisições autenticadas.
- Implementação da recuperação da sessão do usuário e do tratamento de erros de autenticação.
- Configuração das rotas públicas e privadas, incluindo proteção do acesso ao Dashboard.
- Implementação do redirecionamento para Login quando o usuário não estiver autenticado.
- Integração do fluxo de login com o Dashboard, validando a entrada com uma conta de teste previamente criada.
- Criação da estrutura inicial de layout do sistema, incluindo cabeçalho, menu lateral e área principal de conteúdo.
- Implementação da navegação lateral com o acesso ao Dashboard.
- Implementação da exibição do nome do usuário autenticado e da funcionalidade de logout.
- Implementação da alternância entre os temas claro e escuro.
- Criação e organização dos estilos do tema e do layout, incluindo comportamento responsivo inicial.
- Atualização do `main.tsx` para inicializar o tema salvo no `localStorage` ou utilizar a preferência do sistema operacional.
- Implementação da tela inicial do Dashboard com resumo financeiro provisório para a futura integração dos indicadores reais (RF10).

**Próximos passos:**

- Conectar o Dashboard aos endpoints de indicadores financeiros do backend (RF10).
- Substituir os valores provisórios pelos dados reais retornados pela API.
- Implementar a visualização dos indicadores financeiros, incluindo lucro líquido, ganho/hora e ganho/km, conforme os dados disponibilizados pelo backend.
- Validar a apresentação dos dados, os estados de carregamento, erros e ausência de registros.
- Validar a integração dos indicadores com os registros financeiros do usuário autenticado.
- Finalizar e validar o RF10.
- Avançar para as funcionalidades de planos, assinatura e consulta de pagamentos (RF12, RF13 e RF14).

**Dificuldades:**

- Ajustes na organização das rotas e na integração entre o contexto de autenticação, o roteamento e o layout principal.
- Identificação e correção da configuração necessária para evitar a tela em branco durante a integração inicial das rotas.
- Ajustes na inicialização do tema para permitir a recuperação da preferência salva pelo usuário.

**Observações:**

- O frontend utiliza React, TypeScript, Vite, Axios e React Router DOM.
- A autenticação utiliza JWT.
- O backend utiliza NestJS, Prisma e PostgreSQL.
- A estrutura atual do Dashboard é provisória e ainda não representa a conclusão do RF10.
- O resumo financeiro exibido na tela ainda precisa ser validado e integrado aos dados reais da API.
- O tema é inicializado por meio da função `aplicarTemaInicial()`, localizada em `src/utilitarios/tema.ts`.
- A inicialização da aplicação mantém o `BrowserRouter` e o `AutenticacaoProvedor` no `main.tsx`.

### 06/11/2026 - Igor — Implementação do Dashboard e identidade visual do frontend

**O que foi feito:**
- Implementação do Dashboard integrado ao backend para apresentação dos indicadores financeiros do usuário.
- Criação dos filtros de período, permitindo consultar os indicadores de hoje, últimos 7 dias, mês atual e período personalizado.
- Implementação dos cards de resumo financeiro, apresentando faturamento, despesas e lucro líquido.
- Implementação dos indicadores de horas trabalhadas, quilômetros rodados, ganho por hora, ganho por quilômetro e custo por quilômetro.
- Desenvolvimento dos gráficos de faturamento versus despesas por dia e evolução do lucro acumulado.
- Criação dos componentes, serviços, tipos, hooks e utilitários necessários para o funcionamento do Dashboard.
- Aplicação da identidade visual do RouteCash nas telas de login, cadastro e cabeçalho principal, utilizando o logotipo do projeto.
- Ajustes de estilização do cabeçalho e da imagem da marca.
- Realização de testes de navegação, filtros de período, autenticação e isolamento dos dados entre usuários.
- Execução do comando `npm run build`, com compilação bem-sucedida do frontend.

**Próximos passos:**
- Prosseguir com a implementação das próximas funcionalidades previstas no cronograma e no DVP.
- Desenvolver as telas de retaguarda web para consulta e acompanhamento das informações registradas pelo aplicativo mobile.
- Continuar os testes de integração entre frontend, backend e mobile.

**Dificuldades:**
- Ajustes de dimensionamento e alinhamento do logotipo no cabeçalho.
- Adequação da identidade visual da marca aos temas claro e escuro.

**Observações:**
- O Dashboard (RF10) foi implementado e integrado ao backend.
- Foram realizados testes com diferentes usuários para verificar a separação dos dados apresentados.
- O frontend web possui finalidade de retaguarda e visualização, enquanto as operações diárias do motorista são destinadas principalmente ao aplicativo mobile.
- O build de produção foi concluído com sucesso. Foi apresentado apenas um aviso do Vite referente ao tamanho de um dos arquivos JavaScript gerados, sem impedir a compilação.


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
