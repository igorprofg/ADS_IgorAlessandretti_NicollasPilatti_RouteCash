# Relatório de Desenvolvimento — Route Cash

**Data:** 27/10/2026  
**Projeto:** Route Cash  
**Foco do dia:** RF11 — Sincronização offline/online no aplicativo mobile
**Responsável**: Nicollas Pilatti

---

## 1. Objetivo do dia

O trabalho do dia teve como objetivo evoluir o aplicativo mobile do Route Cash para um funcionamento **local-first**, permitindo que o motorista continue utilizando o sistema mesmo quando o backend estiver indisponível.

A arquitetura definida foi:

```text
Ação do usuário
    ↓
SQLite local
    ↓
sync_outbox
    ↓
tentativa de sincronização
    ↓
backend disponível?
    ├─ sim → envia ao servidor + baixa snapshot + reconcilia SQLite
    └─ não → mantém pendente no aparelho
```

O backend continua sendo a fonte central de sincronização entre dispositivos, porém o aplicativo mobile passa a utilizar o SQLite como fonte imediata para leitura e gravação dos principais dados operacionais.

---

## 2. Situação inicial

Antes das alterações realizadas hoje:

- o mobile já possuía autenticação JWT;
- ganhos e despesas já utilizavam parcialmente o endpoint `/sincronizacao/enviar`;
- jornada manual e exclusão de jornada já utilizavam sincronização;
- o backend já possuía:
  - `POST /sincronizacao/enviar`;
  - `GET /sincronizacao/baixar`;
  - tratamento de conflito;
  - timestamps de atualização;
  - processamento individual dos itens;
- ainda existiam fluxos mobile dependentes diretamente da API;
- não havia fluxo offline completo para Ganhos, Despesas e Jornadas;
- a Home dependia parcialmente do backend.

---

# 3. Infraestrutura de sincronização

## 3.1. Snapshot do servidor

Foi validado o download do snapshot completo através de:

```http
GET /sincronizacao/baixar
```

O snapshot contém:

- veículos;
- plataformas;
- categorias de despesa;
- ganhos;
- despesas;
- jornadas;
- data/hora da sincronização.

O teste de download foi concluído com sucesso.

---

## 3.2. Estrutura de sincronização utilizada

### Pasta

```text
mobile/lib/features/sync/
├── data/
│   ├── sync_item_result.dart
│   ├── sync_local_repository.dart
│   ├── sync_outbox_item.dart
│   ├── sync_repository.dart
│   └── sync_snapshot.dart
├── providers/
│   └── sync_providers.dart
├── services/
│   ├── sync_auto_service.dart
│   └── sync_manager.dart
└── presentation/
    └── sync_debug_page.dart
```

---

## 3.3. `sync_local_repository.dart`

Responsável pelo armazenamento local e controle da fila de sincronização.

Principais responsabilidades:

- inserir/atualizar itens na `sync_outbox`;
- evitar duplicidade de eventos do mesmo registro;
- manter apenas o estado mais recente;
- marcar itens como:
  - `pendente`;
  - `atencao`;
- incrementar tentativas de sincronização;
- remover itens já sincronizados;
- gravar dados em:
  - `ganhos_local`;
  - `despesas_local`;
  - `jornadas_local`;
- manter caches de:
  - veículos;
  - plataformas;
  - categorias;
- reconciliar o snapshot do servidor com o SQLite;
- preservar registros locais que ainda estão na outbox.

---

## 3.4. `sync_manager.dart`

Responsável pelo fluxo completo de sincronização.

Fluxo implementado:

```text
syncNow()
    ↓
buscar pendências
    ↓
enviar ganhos
    ↓
enviar despesas
    ↓
enviar jornadas
    ↓
enviar exclusões
    ↓
tratar retorno por item
    ↓
baixar snapshot
    ↓
reconciliar SQLite
```

### Tratamento dos retornos

```text
status: ok / ignorado
→ remove da outbox

ERRO_INTERNO
→ mantém pendente
→ incrementa tentativa

VALIDACAO
NAO_ENCONTRADO
CONFLITO
→ marca como "atencao"
```

O limite de até 50 itens por grupo do backend foi respeitado.

---

## 3.5. Teste da sincronização completa

Foi criada/utilizada uma tela de debug:

```text
mobile/lib/features/sync/presentation/sync_debug_page.dart
```

O teste validou:

- envio de pendências;
- download do servidor;
- reconciliação;
- leitura do SQLite;
- contagem dos registros locais;
- controle da outbox.

Resultado:

```text
SINCRONIZAÇÃO COMPLETA COM SUCESSO
```

---

# 4. Ganhos — migração local-first

## 4.1. Arquivos principais

```text
mobile/lib/features/earnings/
├── data/
│   ├── earning.dart
│   └── earning_repository.dart
├── providers/
│   └── earning_providers.dart
└── presentation/
    ├── earning_form_page.dart
    └── earning_list_page.dart
```

---

## 4.2. Novo comportamento

Ganhos passaram a utilizar o seguinte fluxo:

```text
Novo / Editar / Duplicar ganho
        ↓
ganhos_local
        ↓
sync_outbox
        ↓
SyncManager
        ↓
Servidor
```

### Offline

Quando o backend está indisponível:

- o ganho é salvo no SQLite;
- o lançamento permanece na outbox;
- o aplicativo informa:
  - `Ganho salvo no aparelho. Sincronização pendente.`
- a lista exibe o selo:
  - `Pendente`

### Online

Quando o backend está disponível:

- o ganho é enviado;
- o snapshot é atualizado;
- a outbox é limpa;
- o selo `Pendente` desaparece.

---

## 4.3. Teste offline de Ganhos

Durante os testes foi identificado que o modo avião não impedia a comunicação com o backend por causa de:

```powershell
adb reverse tcp:3000 tcp:3000
```

O celular continuava acessando:

```text
http://127.0.0.1:3000
```

através do cabo USB.

Para simular offline corretamente foi utilizado:

```text
Ctrl + C
```

no backend NestJS.

Resultado:

- ganho criado offline;
- mensagem de sincronização pendente exibida;
- selo pendente exibido;
- registro mantido no SQLite;
- após religar o NestJS, sincronização concluída.

---

# 5. Despesas — migração local-first

## 5.1. Arquivos principais

```text
mobile/lib/features/expenses/
├── data/
│   ├── expense.dart
│   └── expense_repository.dart
├── providers/
│   └── expense_providers.dart
└── presentation/
    ├── expense_form_page.dart
    └── expense_list_page.dart
```

---

## 5.2. Novo comportamento

```text
Nova / Editar despesa
        ↓
despesas_local
        ↓
sync_outbox
        ↓
tentativa de sincronização
```

Offline:

- salva no SQLite;
- mantém pendente;
- exibe aviso;
- mantém o registro disponível no aplicativo.

Online:

- sincroniza;
- remove a pendência;
- atualiza o snapshot local.

---

## 5.3. Categorias de despesa

No modo offline, o formulário utiliza:

```text
categorias_cache
```

As categorias disponíveis são as recebidas na última sincronização.

O cadastro de nova categoria personalizada não foi implementado como operação offline nesta etapa.

---

# 6. AutoSync — sincronização automática

## 6.1. Arquivo criado

```text
mobile/lib/features/sync/services/sync_auto_service.dart
```

---

## 6.2. Problema identificado

Inicialmente o motorista precisava:

1. religar o backend;
2. abrir Ganhos ou Despesas;
3. tocar manualmente no botão de sincronização.

Isso fazia a Home permanecer temporariamente com dados inconsistentes.

---

## 6.3. Solução implementada

Foi implementado um serviço automático de sincronização.

O AutoSync:

- tenta sincronizar quando a conectividade muda;
- tenta sincronizar ao retornar o app para primeiro plano;
- se houver pendências, tenta novamente a cada aproximadamente 15 segundos;
- realiza sincronização completa periodicamente;
- dispara um evento `onSynced` após sucesso.

Isso é importante porque apenas verificar Wi-Fi/dados não é suficiente para saber se o NestJS voltou a responder.

---

## 6.4. Fluxo atual

```text
registro pendente
    ↓
backend indisponível
    ↓
mantém na outbox
    ↓
AutoSync tenta novamente
    ↓
backend volta
    ↓
syncNow()
    ↓
snapshot
    ↓
SQLite atualizado
    ↓
Home notificada
```

O teste foi concluído com sucesso.

---

# 7. Jornadas — migração local-first

## 7.1. Estrutura

```text
mobile/lib/features/journeys/
├── data/
│   ├── journey.dart
│   └── journey_repository.dart
├── providers/
│   └── journey_providers.dart
└── presentation/
    ├── journey_page.dart
    ├── finish_journey_page.dart
    ├── journey_edit_page.dart
    └── manual_journey_page.dart
```

---

## 7.2. Fluxos migrados

Passaram a utilizar SQLite + outbox:

- iniciar jornada;
- finalizar jornada;
- jornada manual;
- editar jornada;
- adicionar quilometragem;
- remover quilometragem;
- excluir jornada.

---

## 7.3. Rotas antigas não utilizadas pelo mobile

Os fluxos mobile deixaram de depender diretamente de:

```http
POST /jornadas/iniciar
PATCH /jornadas/:id/finalizar
PATCH /jornadas/:id

POST /quilometragem
PATCH /quilometragem/:id
DELETE /quilometragem/:id
```

A quilometragem passou a ser parte do estado completo da jornada:

```json
{
  "km_rodados": 120.5
}
```

Para remover:

```json
{
  "km_rodados": null
}
```

---

## 7.4. Validações locais

Foram incluídas verificações de:

- apenas uma jornada em andamento;
- fim posterior ao início;
- jornada não pode estar no futuro;
- limite de km;
- até duas casas decimais;
- sobreposição de jornadas.

O backend continua fazendo a validação definitiva durante a sincronização.

---

## 7.5. Compatibilidades corrigidas

Durante a migração foram corrigidos:

### Provider

`JourneyRepository` passou a exigir:

```dart
localRepository
syncManager
```

O provider foi atualizado para fornecer essas dependências.

### Modelo Journey

Foi mantido o campo:

```dart
String? veiculoPlaca
```

porque a Home já utilizava:

```dart
jornada.veiculoPlaca
```

O repository também passou a carregar:

```sql
v.placa AS veiculo_placa
```

---

## 7.6. Teste offline de Jornada

Teste realizado:

1. NestJS desligado;
2. iniciar jornada;
3. jornada ficou marcada como `Pendente`;
4. NestJS religado;
5. AutoSync enviou a jornada automaticamente;
6. status pendente desapareceu.

Resultado:

```text
Jornada local-first validada com sucesso.
```

---

# 8. Problemas com Riverpod encontrados

Durante o trabalho apareceu algumas vezes:

```text
type 'Null' is not a subtype of type
'SyncLocalRepository' of 'function result'
```

A causa estava relacionada à alteração da árvore de providers durante hot reload/hot restart.

Foi necessário garantir uma única declaração:

```dart
final syncLocalRepositoryProvider =
    Provider<SyncLocalRepository>(
  (ref) {
    return SyncLocalRepository();
  },
);
```

e realizar reinicialização completa:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

Também foi necessário verificar que não existiam declarações duplicadas de:

```text
syncLocalRepositoryProvider
```

---

# 9. Home — funcionamento offline

## 9.1. Problema inicial

A Home utilizava:

```dart
Future.wait([
  userRepository.getMyProfile(),
  earningRepository.findAll(),
  expenseRepository.findAll(),
]);
```

Como o perfil dependia da API, o `Future.wait()` inteiro falhava quando o backend estava indisponível.

---

## 9.2. Ajuste realizado

Foi iniciado o processo para transformar a Home em uma tela baseada em dados locais.

O fluxo pretendido/implementado parcialmente é:

```text
Home
 ↓
ganhos_local
despesas_local
jornadas_local
 ↓
setState
 ↓
indicadores
```

O perfil continua remoto, porém falha de perfil não deve mais impedir o restante da Home de funcionar.

---

## 9.3. Callback do AutoSync

A Home passou a ouvir:

```dart
autoSync.onSynced
```

Quando a sincronização é concluída:

```dart
await _recarregarDashboardLocal();
```

permitindo atualização automática da Home depois que o backend volta.

---

# 10. Indicadores financeiros

As regras já existentes na Home para:

```text
Ganhos
Despesas
Lucro líquido
```

utilizam:

```dart
_totalGanhos
_totalDespesas
_lucro
```

A regra utilizada é:

```text
Lucro = Ganhos - Despesas
```

---

## 10.1. Indicadores planejados para cálculo local

Também foram preparados cálculos locais para:

- horas trabalhadas;
- quilômetros rodados;
- ganho por hora;
- ganho por km;
- custo por km.

Fórmulas:

```text
ganho/hora = lucro líquido / horas trabalhadas

ganho/km = lucro líquido / km rodados

custo/km = despesas / km rodados
```

Com proteção para divisão por zero.

---

# 11. Pendência atual

## Indicadores do período

Ao final do trabalho do dia, a seção:

```text
Indicadores do período
```

ainda **não está funcionando corretamente**.

Apesar de:

- Ganhos;
- Despesas;
- Jornadas;
- SQLite;
- outbox;
- AutoSync;

estarem funcionando, os indicadores adicionais ainda não estão refletindo corretamente os dados carregados localmente.

Essa correção ficou pendente para a próxima sessão.

### Itens a revisar

- leitura de `_journeys`;
- filtro por dia/semana/mês/ano;
- cálculo de horas;
- cálculo de km;
- ganho/hora;
- ganho/km;
- custo/km;
- atualização imediata após finalizar/editar uma jornada offline;
- garantir que não exista dependência residual do backend para os indicadores.

---

# 12. Arquivos principais alterados/criados no dia

## Sync

```text
mobile/lib/features/sync/data/sync_snapshot.dart
mobile/lib/features/sync/data/sync_repository.dart
mobile/lib/features/sync/data/sync_local_repository.dart
mobile/lib/features/sync/data/sync_outbox_item.dart
mobile/lib/features/sync/data/sync_item_result.dart

mobile/lib/features/sync/providers/sync_providers.dart

mobile/lib/features/sync/services/sync_manager.dart
mobile/lib/features/sync/services/sync_auto_service.dart

mobile/lib/features/sync/presentation/sync_debug_page.dart
```

## Ganhos

```text
mobile/lib/features/earnings/data/earning_repository.dart
mobile/lib/features/earnings/providers/earning_providers.dart
mobile/lib/features/earnings/presentation/earning_form_page.dart
mobile/lib/features/earnings/presentation/earning_list_page.dart
```

## Despesas

```text
mobile/lib/features/expenses/data/expense_repository.dart
mobile/lib/features/expenses/providers/expense_providers.dart
mobile/lib/features/expenses/presentation/expense_form_page.dart
mobile/lib/features/expenses/presentation/expense_list_page.dart
```

## Jornadas

```text
mobile/lib/features/journeys/data/journey.dart
mobile/lib/features/journeys/data/journey_repository.dart
mobile/lib/features/journeys/providers/journey_providers.dart

mobile/lib/features/journeys/presentation/journey_page.dart
mobile/lib/features/journeys/presentation/finish_journey_page.dart
mobile/lib/features/journeys/presentation/journey_edit_page.dart
mobile/lib/features/journeys/presentation/manual_journey_page.dart
```

## Home

```text
mobile/lib/features/home/presentation/home_page.dart
```

---

# 13. Estado atual do RF11

## Funcionando

- [x] SQLite local
- [x] `sync_outbox`
- [x] criação de ganho offline
- [x] edição de ganho offline
- [x] duplicação de ganho
- [x] exclusão de ganho
- [x] criação de despesa offline
- [x] edição de despesa offline
- [x] exclusão de despesa
- [x] iniciar jornada offline
- [x] finalizar jornada offline
- [x] jornada manual offline
- [x] edição de jornada
- [x] quilometragem na jornada
- [x] exclusão de jornada
- [x] download de snapshot
- [x] reconciliação SQLite
- [x] envio automático ao voltar o backend
- [x] AutoSync
- [x] status pendente
- [x] atualização automática após sincronização

## Pendente

- [ ] corrigir completamente os indicadores do período na Home;
- [ ] revisar cálculo local de horas/km;
- [ ] validar ganho/hora;
- [ ] validar ganho/km;
- [ ] validar custo/km;
- [ ] melhorar visualização global do status de sincronização;
- [ ] tratar visualmente itens em estado `atencao`;
- [ ] realizar bateria final de testes do RF11.

---

# 14. Resultado do dia

O aplicativo mobile do Route Cash passou de um modelo predominantemente dependente da API para um modelo **local-first funcional** nos três principais módulos operacionais:

```text
Ganhos
Despesas
Jornadas
```

O motorista agora consegue registrar dados mesmo quando o backend está indisponível, mantendo as alterações no dispositivo e sincronizando automaticamente quando o servidor volta.

A infraestrutura principal do RF11 está funcional.

A principal pendência técnica restante é garantir que todos os **indicadores financeiros e operacionais da Home sejam calculados e atualizados integralmente com os dados locais**, independentemente do estado da conexão com o backend.
