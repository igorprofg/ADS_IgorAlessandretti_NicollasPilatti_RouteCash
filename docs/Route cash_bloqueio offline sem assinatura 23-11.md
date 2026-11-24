# ROUTE CASH — RELATÓRIO TÉCNICO DE IMPLEMENTAÇÃO E VALIDAÇÃO

**Tema:** Controle de acesso por assinatura, autorização offline, bloqueio de lançamentos e sincronização  
**Data:** 23 de novembro de 2026  
**Responsável:** Nicollas Pilatti  
**Projeto:** Route Cash — Trabalho de Conclusão de Curso / Análise e Desenvolvimento de Sistemas  
**Ambiente de validação:** Backend NestJS em desenvolvimento local; aplicativo Flutter executado em dispositivo Android físico; banco PostgreSQL no backend e SQLite no dispositivo; Asaas Sandbox para os fluxos de pagamento previamente testados.  
**Situação geral:** Fluxo de autorização offline e bloqueio de lançamentos de **Ganhos** validado nos cenários descritos; integração integral de contratação e cobertura de todos os módulos ainda pendentes.

---

## 1. Objetivo

Documentar as alterações e os testes realizados no Route Cash para controlar operações de escrita conforme a situação da assinatura, preservando a proposta *local-first* do aplicativo. O motorista com assinatura ativa deve poder continuar registrando informações por um período limitado sem conexão com o backend, e os dados criados localmente devem ser sincronizados quando a conectividade retornar.

O trabalho teve como objetivos específicos:

- Consultar e apresentar a situação da assinatura no aplicativo Flutter.
- Impedir novos lançamentos quando não houver autorização válida.
- Permitir a utilização offline por até sete dias mediante concessão assinada pelo backend.
- Encerrar a autorização local quando seu prazo expirar, mesmo que o backend permaneça indisponível.
- Preservar informações já gravadas no SQLite e pendências da fila de sincronização.
- Retomar o acesso quando o backend confirmar novamente uma assinatura ativa.
- Manter a proteção das operações financeiras no servidor, sem depender apenas da interface mobile.

> **Escopo da comprovação:** Os testes funcionais de bloqueio, expiração e desbloqueio descritos neste relatório foram realizados com o fluxo de **Ganhos**. Isso não equivale à homologação automática das operações de **Despesas** e **Jornadas**.

## 2. Arquitetura e responsabilidades

| Componente | Responsabilidade |
|---|---|
| Backend NestJS | Consultar assinatura, avaliar vigência, emitir autorização offline assinada e impor bloqueios nas rotas protegidas. |
| PostgreSQL / Prisma | Manter o estado oficial da assinatura, seus vínculos e datas de vigência. |
| Flutter | Consultar o backend, validar a concessão offline, decidir se a operação local pode começar e apresentar o estado de acesso. |
| `flutter_secure_storage` | Armazenar o token de autorização por usuário no dispositivo. |
| SQLite | Manter os lançamentos e dados necessários ao uso local-first. |
| `sync_outbox` / AutoSync | Conservar operações pendentes e tentar enviá-las quando o backend estiver acessível. |
| Asaas Sandbox / webhooks | Processar o fluxo de contratação e atualização financeira; integração já testada anteriormente, mas checkout iniciado pelo Flutter ainda não concluído. |

### 2.1. Fluxo lógico de autorização

```text
Assinatura ativa e vigente no backend
           |
           v
GET /assinaturas/autorizacao-offline  (JWT)
           |
           v
Backend emite token assinado com Ed25519
           |
           v
Flutter verifica assinatura, usuário e expiração
           |
           v
Armazena autorização em armazenamento seguro
           |
      +----+--------------------+
      |                         |
      v                         v
Backend disponível       Backend indisponível
Consulta/renovação       Verificação do token local
      |                         |
      v                         v
Acesso liberado         Válido? -> permite novos lançamentos
                        Expirado/ausente? -> bloqueia
                                  |
                                  v
                         Dados anteriores preservados
```

**Regra temporal importante:** Os sete dias contam a partir da **emissão da autorização pelo servidor**, e não do momento em que a rede ou o backend é desligado. A vigência efetiva também é limitada pela data de vencimento da assinatura, conforme a regra de emissão do backend.

## 3. Componentes implementados ou integrados

### 3.1. Backend: consulta e proteção de assinatura

Endpoints e comportamentos trabalhados:

- `GET /assinaturas/atual`: consulta do estado atual da assinatura exibido na Home do Flutter.
- `GET /assinaturas/autorizacao-offline`: emissão de uma concessão assinada quando a assinatura está ativa e vigente.
- `POST /sincronizacao/enviar`: protegido por regra de assinatura; tentativas sem assinatura autorizada retornaram **HTTP 403** com identificação `ASSINATURA_NECESSARIA` nos testes anteriores.
- Operações financeiras protegidas pelo `AssinaturaAtivaGuard`, conforme integração realizada no backend.
- `GET /sincronizacao/baixar`: mantido acessível nas condições previstas para permitir recuperação e leitura de dados; isso não deve ser confundido com autorização para enviar lançamentos.

O estado oficial da assinatura permanece no servidor. A autorização offline é uma concessão temporária para a execução local; **não é uma forma de ignorar os guards do backend**. Quando houver sincronização, o servidor continua avaliando se aceita os dados enviados.

### 3.2. Backend: emissão de token Ed25519

A autorização offline utiliza o formato:

```text
base64url(payload JSON) + "." + base64url(assinatura Ed25519)
```

O payload inclui identificadores e metadados necessários à verificação, como versão, tipo, usuário (`sub`), assinatura (`sid`), emissão (`iat`) e expiração (`exp`). A chave **privada** permanece no backend. A chave **pública** é fornecida ao Flutter para validar a autenticidade do token.

O prazo normal é de **até sete dias**, respeitando o vencimento da assinatura. Não é necessário consultar o backend a cada gravação offline para validar criptograficamente o token armazenado.

### 3.3. Flutter: `OfflineAuthorizationService`

Arquivo de referência:

`mobile/lib/features/subscriptions/services/offline_authorization_service.dart`

Responsabilidades implementadas:

- `renovarSilenciosamente()`: chama `/assinaturas/autorizacao-offline`, verifica a concessão e a armazena somente após validação bem-sucedida.
- `possuiAutorizacaoValida()`: valida a concessão local sem exigir conexão.
- `expiracaoLocalValida()`: obtém a expiração de um token local válido para permitir a apresentação do prazo.
- `autorizarEscrita()`: tenta a renovação online e, diante de indisponibilidade, utiliza uma concessão local ainda válida.
- `limparUsuarioAtual()`: remove a concessão armazenada da conta, sem apagar o SQLite ou a fila de sincronização.
- `_verificarToken()`: verifica formato, versão, usuário, período, chave pública e assinatura digital Ed25519.

A concessão é armazenada sob uma chave específica por usuário (`routecash_offline_authorization_v1_<userId>`), evitando uso direto de uma autorização vinculada a outra conta.

**Tratamento de erros:** O serviço diferencia falhas transitórias da API de respostas HTTP 401/403. Quando essas respostas são recebidas, a concessão local correspondente é removida. Uma falha de rede ou timeout, por si só, não apaga uma autorização ainda válida.

### 3.4. Flutter: bloqueio de operações de escrita

A integração de controle de acesso é feita por serviço compartilhado de verificação de assinatura, utilizado nos fluxos de gravação do aplicativo. Nos testes realizados no módulo de **Ganhos**:

- Uma autorização vigente permitiu criar lançamentos offline.
- Uma autorização expirada impediu criar novo ganho com o backend indisponível.
- Após restabelecer a conexão e consultar novamente uma assinatura ativa, foi possível salvar um novo ganho.

**Limitação do escopo:** É necessário revisar e testar separadamente todos os pontos de escrita em **Despesas** e **Jornadas**, inclusive cadastro, edição, exclusão, duplicação, início e encerramento de jornada, conforme os fluxos disponíveis.

### 3.5. Interface da Home

A Home apresenta a assinatura como **ativa** quando a consulta online é bem-sucedida. Quando não há acesso ao backend, pode apresentar o modo offline autorizado com seu prazo restante, desde que exista concessão válida.

Durante um teste curto, a exibição inicial foi `0 d e 0 hrs`, embora ainda restassem minutos; isso apontou uma limitação de formatação para períodos inferiores a uma hora. O bloqueio de expiração foi comprovado, independentemente desse detalhe visual. Recomenda-se garantir a exibição de minutos e segundos em prazos curtos.

### 3.6. Preservação e sincronização

A arquitetura mantém os registros locais no **SQLite** e os envios pendentes na **`sync_outbox`**. Após a reconexão, o AutoSync envia os registros que puderem ser processados e reconcilia o estado local.

O bloqueio de assinatura não deve ser usado como gatilho para exclusão de lançamentos ou limpeza das pendências. Em cenário de expiração, a leitura dos dados existentes deve permanecer disponível.

## 4. Problema identificado e correção aplicada

### 4.1. Sintoma observado

Nos primeiros testes, a Home mostrava corretamente **“Assinatura ativa”** com o backend ligado. Contudo, ao desligá-lo, aparecia **“Sem conexão para consultar assinatura”** e a autorização offline não era reconhecida.

### 4.2. Causa encontrada

A validação do Flutter utiliza a chave pública SPKI/DER informada em tempo de compilação:

```dart
static const String _publicKeySpkiB64 = String.fromEnvironment(
  'OFFLINE_PUBLIC_KEY_B64',
  defaultValue: '',
);
```

Sem a opção `--dart-define=OFFLINE_PUBLIC_KEY_B64=...`, o valor ficava vazio e a validação de tokens retornava `false`. O backend podia emitir um token correto, mas o aplicativo não o aceitava para uso offline.

### 4.3. Solução

A chave pública do backend passou a ser fornecida corretamente na execução/compilação do Flutter, sem incluir a chave privada no aplicativo:

```powershell
flutter run --dart-define="OFFLINE_PUBLIC_KEY_B64=$chavePublica"
```

O sinal `=` de preenchimento no final da representação Base64, quando presente, foi mantido como parte da chave. Como `String.fromEnvironment` é resolvido durante a compilação, a configuração exige nova execução compilada; *hot reload* não substitui essa etapa.

Após esse ajuste, a autorização passou a ser validada e a contagem de sete dias apareceu corretamente ao deixar o backend indisponível.

**Ação preventiva:** Garantir que a mesma chave pública seja passada nas compilações futuras, inclusive APKs de demonstração. Nunca incorporar ou publicar a chave privada do NestJS.

## 5. Testes executados e evidências observadas

Os testes abaixo foram acompanhados durante a sessão de desenvolvimento de **23/11/2026**. São evidências funcionais manuais no ambiente descrito; não representam uma suíte automatizada ou homologação de produção.

| Nº | Cenário | Evidência observada | Resultado |
|---|---|---|---|
| T01 | Conta com assinatura ativa e backend acessível | Home exibiu “Assinatura ativa”. | **Aprovado** |
| T02 | Emissão e verificação da concessão assinada | Log Flutter registrou `[TESTE OFFLINE] Token novo válido: true`. | **Aprovado** |
| T03 | Desligamento do backend com concessão normal | Home apresentou a contagem de sete dias após correção da chave pública. | **Aprovado** |
| T04 | Criação de registros com autorização offline válida | O aplicativo permitiu lançamentos durante a indisponibilidade. | **Aprovado no fluxo testado** |
| T05 | Retorno do backend após registros offline | Usuário confirmou que os registros foram enviados ao backend e a Home voltou a mostrar assinatura ativa. | **Aprovado** |
| T06 | Emissão de autorização curta de teste | Backend registrou `NODE_ENV: undefined`, `Flag: true`, `Prazo em segundos: 120`. | **Aprovado em desenvolvimento** |
| T07 | Validação do token curto | Flutter registrou `[TESTE OFFLINE] Token novo válido: true`. | **Aprovado** |
| T08 | Expiração com backend desligado | Após aproximadamente dois minutos, novos lançamentos deixaram de ser permitidos. | **Aprovado em Ganhos** |
| T09 | Preservação após expiração | Os registros previamente existentes continuaram visíveis. | **Aprovado** |
| T10 | Reconexão após expiração | A Home voltou para “Assinatura ativa”. | **Aprovado** |
| T11 | Desbloqueio após reconexão | Usuário conseguiu salvar novamente um ganho. | **Aprovado** |
| T12 | Retorno ao prazo normal | Após correção/restauração da configuração e da chave, o contador de sete dias voltou a aparecer. | **Aprovado** |

### 5.1. Sequência do teste de expiração acelerada

Para testar sem aguardar sete dias, o backend foi configurado **temporariamente** para emitir uma concessão com validade de **120 segundos**, preservando a assinatura criptográfica Ed25519. A condição de teste foi controlada por variável de ambiente exclusiva de desenvolvimento (`OFFLINE_TESTE_120S=true`).

Sequência observada:

1. Backend confirmou prazo configurado de 120 segundos.
2. Flutter recebeu e validou o token (`true`).
3. Backend foi desligado.
4. Home passou a apresentar a duração curta; inicialmente, a formatação em dias/horas aparecia zerada.
5. Após expirar, o aplicativo tentou consultar a assinatura e bloqueou novos lançamentos.
6. Registros anteriores continuaram visíveis no aplicativo.
7. Backend foi religado, a Home voltou para “Assinatura ativa” e um novo ganho pôde ser salvo.
8. O prazo normal de sete dias foi restaurado; sua visualização offline voltou a funcionar após regularização da chave pública na execução do Flutter.

**Conclusão do teste:** A indisponibilidade prolongada não concede acesso ilimitado. A autorização expira localmente, impede novos lançamentos no fluxo validado e não apaga dados anteriores.

### 5.2. O que não foi demonstrado nesse teste

- Expiração real depois de sete dias corridos sem conexão — foi simulada de maneira funcional com 120 segundos.
- Bloqueio integral de todas as ações de Despesas e Jornadas.
- Todos os casos de cancelamento, suspensão administrativa e inadimplência em conjunto com um token offline ainda válido.
- Homologação em produção, múltiplos aparelhos, recuperação de relógio alterado ou cenários adversariais.

## 6. Regras de negócio confirmadas e pontos de atenção

### 6.1. Concessão de sete dias

- A concessão é emitida somente após avaliação de assinatura ativa/vigente pelo backend.
- É assinada pelo servidor e verificada pelo aplicativo.
- Pertence a um usuário específico e inclui data de validade.
- Não pode ser estendida localmente sem nova autorização assinada.
- A expiração limita novas operações no dispositivo, sem excluir histórico existente.
- Se o backend estiver acessível, o aplicativo pode obter uma autorização renovada.

### 6.2. Cancelamento e janela offline

Uma autorização **já emitida** pode continuar tecnicamente válida durante a ausência de conexão até o prazo assinado, porque o aparelho não tem como conhecer uma mudança de situação ocorrida posteriormente no backend. Assim, o limite de sete dias é um compromisso de funcionamento offline, e não uma revogação instantânea em um dispositivo isolado da rede.

Quando o app recebe resposta **401/403** ao tentar renovar, o serviço remove sua concessão local. O backend continua com a palavra final para aceitar ou rejeitar lançamentos enviados.

É necessário **alinhar formalmente** a política de cancelamento: bloqueio imediato ao ter conhecimento da revogação, eventual direito de uso até o final de um período já pago e como tratar lançamentos feitos enquanto o dispositivo ainda tinha uma concessão válida mas o servidor já havia cancelado a assinatura.

### 6.3. Sincronização de dados pendentes

Se a assinatura estiver inativa quando os dados forem enviados, o backend pode rejeitar o upload. A aplicação deve manter a fila e dar transparência ao usuário, sem apagar o registro nem marcar a pendência como sincronizada.

Também foi identificado um ponto de atenção no AutoSync: a conclusão de uma sincronização que apenas **baixou** dados não prova, por si só, que a assinatura voltou a estar ativa. A liberação deve ser baseada em verificação explícita da assinatura, e não apenas no sucesso genérico de `syncNow()`.

### 6.4. Desligar o backend não equivale a desligar toda a internet

Os testes utilizaram a indisponibilidade do backend local como simulação do cenário offline. É recomendável repetir pelo menos um teste sem rede no próprio dispositivo para verificar a experiência sem conectividade, timeouts e retomada da conexão.

## 7. Configuração permanente e limpeza do ambiente de testes

As alterações temporárias de diagnóstico não fazem parte da regra final. A configuração definitiva deve observar:

1. **Backend:** emitir concessões com validade máxima normal de sete dias, limitada ao vencimento da assinatura.
2. **Ambiente:** remover/desabilitar `OFFLINE_TESTE_120S=true`; não manter simulação acidentalmente habilitada.
3. **Logs:** retirar `console.log` e `debugPrint` temporários identificados como `[TESTE OFFLINE]`, ou substituí-los por logs técnicos seguros e condicionados ao modo de depuração.
4. **Flutter:** manter `String.fromEnvironment('OFFLINE_PUBLIC_KEY_B64')`, Ed25519 e `flutter_secure_storage`.
5. **Build:** documentar a injeção de `OFFLINE_PUBLIC_KEY_B64` na configuração de execução e nas compilações de APK.
6. **Segredos:** nunca distribuir a chave **privada** do backend nem registrar tokens completos em logs.
7. **Dados locais:** não desinstalar o app nem limpar armazenamento do dispositivo para testar autorização; isso pode comprometer o banco local.

**Observação:** A validade máxima de sete dias também é verificada no Flutter, mas **não é definida apenas pelo Flutter**. A duração concreta de cada autorização é determinada pelo `exp` assinado na emissão do token pelo backend.

## 8. Pendências e próximos passos

| Prioridade | Item | Responsável sugerido | Critério de conclusão |
|---|---|---|---|
| Alta | Revisar proteção em **Despesas** e **Jornadas** | Nicollas — Mobile | Criação, edição e demais operações de escrita não são aceitas com autorização expirada. |
| Alta | Validar fila de sincronização quando o backend responde 403 | Nicollas + backend | Pendências preservadas, erro comunicado corretamente e nenhuma baixa indevida da outbox. |
| Alta | Revisar confirmação de reativação no AutoSync | Nicollas — Mobile | A assinatura não é considerada ativa só porque um download de snapshot terminou. |
| Alta | Integrar “Contratar plano” ao checkout Asaas | Nicollas + responsável do backend/web | Flutter obtém URL de checkout, abre o pagamento e reconhece ativação após webhook. |
| Média | Melhorar contador de minutos/segundos | Nicollas — Mobile | Prazo inferior a uma hora mostrado sem ambiguidade. |
| Média | Exibir estado de assinatura cancelada a partir de histórico, quando aplicável | Nicollas + backend | Não confundir cancelamento com “nenhuma assinatura encontrada”. |
| Média | Documentar política de cancelamento/uso offline | Equipe | Política aprovada e consistente entre backend, Flutter e requisitos acadêmicos. |
| Média | Registrar testes automatizados de serviço e guards | Equipe | Casos de token válido, expirado, inválido, 401/403 e reconexão cobertos. |
| Média | Testar dispositivo sem rede, múltiplas sessões e builds de demonstração | Nicollas — Mobile | Chave pública presente nos builds, sem perda de dados e com mensagens coerentes. |
| Posterior | Homologação de produção e deploy | Equipe | Configuração de segredos, HTTPS, domínio, webhook estável e checklist de segurança aprovados. |

### 8.1. Integração do checkout Asaas — ainda pendente no Flutter

O fluxo financeiro no backend já teve testes anteriores com Asaas Sandbox, incluindo webhook, pagamento e ativação de assinatura. Ainda resta ligar a experiência de contratação no aplicativo:

```text
Flutter: selecionar plano
    -> POST /assinaturas/asaas
    -> receber checkout_url
    -> abrir checkout seguro do Asaas
    -> pagamento no Sandbox
    -> webhook atualiza assinatura no backend
    -> Flutter consulta assinatura atual
    -> Home informa "Assinatura ativa"
    -> nova autorização offline pode ser emitida
```

Esse trabalho deve respeitar os contratos já combinados com a equipe e evitar alterações não coordenadas nos módulos de administração e nas migrations.

## 9. Conclusão

Em **23/11/2026**, o responsável **Nicollas Pilatti** concluiu e validou, nos cenários executados, o funcionamento central do **controle de assinatura offline em Ganhos** do Route Cash. A aplicação passou a reconhecer concessões Ed25519 válidas, operar sem conexão durante a vigência, bloquear novos lançamentos após expiração, preservar os dados existentes e restabelecer o acesso quando o backend voltou a confirmar a assinatura ativa.

A falha que impedia a contagem offline foi solucionada ao configurar corretamente a **chave pública na compilação do Flutter**. O teste acelerado de **120 segundos** demonstrou a expiração e o bloqueio sem a necessidade de aguardar sete dias reais. Ao restaurar a configuração normal, o aplicativo voltou a exibir a contagem da autorização de sete dias.

**Status da entrega:** Funcionalidade central **validada no fluxo de Ganhos e no ambiente de desenvolvimento**. Antes de considerá-la totalmente concluída para o projeto, faltam a cobertura e os testes de Despesas/Jornadas, o tratamento dos cenários de cancelamento/sincronização pendente, pequenos aprimoramentos de interface e a integração da contratação pelo Flutter com o checkout Asaas.

---

**Responsável pelo relatório:** Nicollas Pilatti  
**Data de emissão:** 23/11/2026  
**Finalidade:** Registro técnico de implementação, evidências de teste e alinhamento das próximas entregas do projeto acadêmico Route Cash.
