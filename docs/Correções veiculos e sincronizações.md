# Route Cash — Relatório Técnico de Correção de Veículos e Sincronização Dependente

**Projeto:** Route Cash  
**Módulo:** Backend + Mobile  
**Data:** 13/11/2026  
**Status:** Correção concluída e validada com sucesso  
**Escopo:** regra de unicidade de placa por usuário + recuperação automática de ganhos/jornadas bloqueados por dependência de veículo

---

## 1. Objetivo deste documento

Este documento registra uma correção realizada no projeto **Route Cash** após a identificação de um problema de sincronização entre o aplicativo mobile e o backend.

O erro foi encontrado durante um teste real de uso do aplicativo mobile ao longo do dia, com lançamentos sendo feitos offline e posteriormente sincronizados com o backend.

O comportamento observado inicialmente foi:

```text
Plataformas sincronizaram normalmente
Ganhos não apareceram no Prisma
Jornadas não apareceram no Prisma
```

A investigação mostrou que o problema não estava no mecanismo geral de sincronização, pois a plataforma criada offline foi enviada corretamente.

A causa estava relacionada ao veículo utilizado pelos lançamentos.

---

## 2. Cenário que revelou o problema

Durante o teste foi utilizado, em uma segunda conta, um veículo cuja placa já estava cadastrada em outra conta.

O mobile permitiu a criação local do veículo porque o cadastro foi realizado em modo **local-first**.

Posteriormente, durante a sincronização, o backend recusou o veículo devido à regra anterior:

```text
placa única no sistema inteiro
```

Mesmo assim, ganhos e jornadas já haviam sido registrados localmente utilizando o UUID desse veículo.

O resultado foi uma cascata de erros de dependência.

---

## 3. Fluxo do erro identificado

O comportamento anterior era equivalente a:

```text
Conta A
→ veículo ABC1D23 cadastrado

Conta B
→ cadastra localmente ABC1D23
→ mobile aceita porque está offline
→ veículo entra na outbox

Sync
→ backend detecta que ABC1D23 já existe em outra conta
→ veículo recebe CONFLITO
→ veículo não é criado no Prisma

Depois:

Ganho da Conta B
→ referencia id_veiculo local
→ backend procura o veículo
→ não encontra
→ NAO_ENCONTRADO

Jornada da Conta B
→ referencia o mesmo id_veiculo
→ backend procura o veículo
→ não encontra
→ NAO_ENCONTRADO
```

---

## 4. Diagnóstico da sincronização

Foi confirmado que o fluxo geral da sincronização estava funcionando.

Os seguintes componentes estavam corretos:

- autenticação;
- conexão mobile → backend;
- endpoint `POST /sincronizacao/enviar`;
- envio de plataformas;
- funcionamento da outbox;
- envio por entidade;
- processamento dos resultados;
- download do snapshot;
- reconciliação.

O problema estava especificamente nas dependências dos lançamentos.

Ganhos e jornadas exigem um veículo válido no backend.

---

## 5. Validação de veículo no backend

O backend possui uma validação equivalente a:

```text
id_veiculo deve existir
id_veiculo deve pertencer ao usuário
veículo deve estar ativo
```

Consequentemente:

```text
veículo recusado
↓
ganho recusado
jornada recusada
```

Essa relação entre entidades estava correta do ponto de vista de integridade.

O problema real era a regra de placa global e o fato de registros dependentes permanecerem presos em estado de atenção mesmo após a correção da dependência.

---

## 6. Comportamento da outbox

Quando ganho ou jornada recebiam:

```text
NAO_ENCONTRADO
```

o mobile convertia o item para:

```text
estado = atencao
```

Isso impedia novas tentativas automáticas.

O método responsável por buscar pendências considerava somente:

```text
estado = pendente
```

Portanto, mesmo depois que o veículo fosse corrigido e sincronizado, ganhos e jornadas continuavam presos em:

```text
atencao
```

e não eram reenviados automaticamente.

---

## 7. Duas correções definidas

Foram definidas duas melhorias:

### Correção 1 — placa única por usuário

A regra anterior:

```text
placa única globalmente
```

foi substituída por:

```text
placa única por usuário
```

Assim, usuários diferentes podem cadastrar o mesmo veículo.

### Correção 2 — reprocessamento de dependências

Itens em estado:

```text
atencao / NAO_ENCONTRADO
```

podem voltar automaticamente para:

```text
pendente
```

quando suas dependências passam a existir corretamente no servidor.

---

## 8. Nova regra de negócio para placa

Antes:

```text
Conta A → ABC1D23 ✅
Conta B → ABC1D23 ❌
```

Depois:

```text
Conta A → ABC1D23 ✅
Conta B → ABC1D23 ✅
```

Mas continua inválido dentro da mesma conta:

```text
Conta A → ABC1D23 ✅
Conta A → ABC1D23 novamente ❌
```

Essa regra é mais coerente para o Route Cash, pois um mesmo veículo pode ser utilizado por diferentes motoristas.

Exemplo:

```text
carro compartilhado
motoristas diferentes
contas diferentes
mesma placa
```

---

## 9. Arquivo alterado — `schema.prisma`

Arquivo:

```text
backend/prisma/schema.prisma
```

Regra anterior:

```prisma
placa String? @unique @db.VarChar(10)
```

Regra atual:

```prisma
placa String? @db.VarChar(10)
```

A restrição global de unicidade foi removida do campo.

---

## 10. Migration do banco

Foi criada uma migration específica para alterar a unicidade da placa.

Arquivo equivalente a:

```text
backend/prisma/migrations/<timestamp>_placa_unica_por_usuario/migration.sql
```

A migration remove o índice global antigo:

```sql
DROP INDEX IF EXISTS "veiculo_placa_key";
```

e cria um índice único parcial:

```sql
CREATE UNIQUE INDEX "veiculo_id_usuario_placa_key"
ON "veiculo" ("id_usuario", "placa")
WHERE "placa" IS NOT NULL;
```

Com isso, o PostgreSQL passa a garantir diretamente:

```text
mesmo usuário + mesma placa → conflito
usuários diferentes + mesma placa → permitido
placa nula → permitido
```

---

## 11. Arquivo alterado — `veiculos.service.ts`

Arquivo:

```text
backend/src/veiculos/veiculos.service.ts
```

O método de validação de placa foi refeito.

Antes, a busca era global.

Conceitualmente:

```typescript
findUnique({
  where: {
    placa,
  },
});
```

Depois passou a considerar o usuário:

```typescript
findFirst({
  where: {
    id_usuario: usuarioId,
    placa: placaNormalizada,
  },
});
```

---

## 12. Nova regra de `validarPlacaLivre`

O método agora verifica:

```text
usuário atual
+
placa normalizada
+
veículo diferente do atual em caso de edição
```

Fluxo:

```text
placa vazia
→ permitido

placa não existe para o usuário
→ permitido

placa existe em veículo ativo do mesmo usuário
→ conflito

placa existe em veículo inativo do mesmo usuário
→ orienta reativação

placa existe em outro usuário
→ permitido
```

---

## 13. Normalização da placa

A placa passou a ser normalizada com:

```typescript
placa?.trim()
```

Isso evita diferenças artificiais como:

```text
ABC1D23
ABC1D23 
```

A aplicação passa a considerar ambos como a mesma placa.

---

## 14. Tratamento de veículo inativo

Foi mantido o comportamento especial para veículo removido.

Se o usuário tentar cadastrar uma placa que já existe em um veículo inativo da própria conta, o backend retorna conflito informando que o veículo deve ser reativado.

Resposta conceitual:

```json
{
  "statusCode": 409,
  "error": "Conflict",
  "message": "Você já tem um veículo removido com essa placa. Reative-o na lista de inativos",
  "id_veiculo_inativo": "..."
}
```

Isso evita duplicar veículos históricos.

---

## 15. Método `erroPlaca`

O método de tratamento de erro `P2002` foi mantido.

Objetivo: proteger contra duas requisições simultâneas.

Exemplo:

```text
Requisição A verifica placa → livre
Requisição B verifica placa → livre

A grava primeiro
B tenta gravar logo depois
```

O índice do PostgreSQL impede a duplicação.

O backend converte o erro para:

```text
409 Conflict
```

com mensagem adequada.

---

## 16. `create()` ajustado

Na criação do veículo:

1. placa é normalizada;
2. `validarPlacaLivre()` é executado;
3. veículo é criado;
4. eventual `P2002` é convertido em conflito legível.

Fluxo:

```text
create()
→ trim da placa
→ validar por usuário
→ Prisma create
→ banco valida índice
```

---

## 17. `update()` ajustado

Na edição, a placa é validada somente quando o campo realmente vem no DTO.

Isso evita revalidar desnecessariamente a placa em um PATCH que altere apenas outro campo.

Exemplo:

```text
alterar apenas modelo
→ placa não enviada
→ não precisa validar placa novamente
```

---

## 18. Arquivo alterado — `sincronizacao.service.ts`

Arquivo:

```text
backend/src/sincronizacao/sincronizacao.service.ts
```

A mesma regra de placa foi aplicada no fluxo RF11.

Isso evita inconsistência entre:

```text
CRUD normal
```

e:

```text
sincronização offline
```

Agora ambos seguem a mesma regra de negócio.

---

## 19. Validação de placa durante RF11

Antes:

```text
procura placa em qualquer usuário
```

Depois:

```text
procura placa somente em:
id_usuario = usuário autenticado
```

Consequentemente:

```text
mesma placa em outra conta
→ não interfere

mesma placa na própria conta
→ conflito
```

---

## 20. Arquivo alterado — `sync_local_repository.dart`

Arquivo:

```text
mobile/lib/features/sync/data/sync_local_repository.dart
```

Foi adicionada lógica para recuperar registros em atenção quando a dependência já foi resolvida.

Método criado:

```dart
requeueResolvedDependencyAttention()
```

---

## 21. Objetivo de `requeueResolvedDependencyAttention`

O método procura entradas da outbox com:

```text
estado = atencao
codigo_erro = NAO_ENCONTRADO
operacao = upsert
```

e verifica se as dependências necessárias já estão disponíveis.

Dependências verificadas:

### Ganho

```text
veículo válido
plataforma válida
```

### Despesa

```text
veículo válido
categoria válida
```

### Jornada

```text
veículo válido
```

---

## 22. Uso do snapshot como confirmação

O método é executado depois de baixar e reconciliar o snapshot.

Isso é importante porque o cache local pode conter dados antigos.

Fluxo:

```text
envia pendências
↓
baixa snapshot
↓
reconcilia caches
↓
verifica dependências confirmadas
↓
recoloca registros elegíveis em pendente
```

Assim, a aplicação não confia apenas no fato de um veículo existir localmente.

---

## 23. Dependências ainda pendentes

Se a própria dependência ainda possui uma entrada na outbox, ela não é considerada resolvida.

Exemplo:

```text
ganho depende do veículo X

veículo X ainda está:
pendente
ou
atencao
```

Resultado:

```text
ganho permanece em atencao
```

Somente quando o veículo estiver confirmado a aplicação libera o ganho novamente.

---

## 24. Reativação da entrada da outbox

Quando a dependência está resolvida, o item volta para:

```text
estado = pendente
codigo_erro = null
motivo_erro = null
tentativas = 0
```

A data de atualização da outbox também é renovada.

---

## 25. Arquivo alterado — `sync_manager.dart`

Arquivo:

```text
mobile/lib/features/sync/services/sync_manager.dart
```

O fluxo de `syncNow()` foi ampliado.

Antes:

```text
_sendPending()
↓
_downloadAndReconcile()
```

Depois:

```text
_sendPending()
↓
_downloadAndReconcile()
↓
requeueResolvedDependencyAttention()
↓
houve itens recuperados?
  ↓ sim
_sendPending()
↓
_downloadAndReconcile()
```

---

## 26. Benefício do novo fluxo

Antes:

```text
veículo falhou
↓
ganho falhou
↓
usuário corrige veículo
↓
veículo sincroniza
↓
ganho continua parado em atencao
```

Agora:

```text
veículo falhou
↓
ganho falhou
↓
usuário corrige veículo
↓
veículo sincroniza
↓
snapshot confirma veículo
↓
ganho volta para pendente
↓
ganho sincroniza
```

O mesmo princípio vale para jornadas e, quando aplicável, despesas.

---

## 27. Recuperação dos lançamentos existentes

A correção foi criada também para preservar os registros que já tinham sido feitos durante o teste.

Não foi necessário:

- apagar banco;
- apagar aplicativo;
- recriar ganhos;
- recriar jornadas;
- editar manualmente todos os lançamentos.

Os próprios registros existentes foram reutilizados.

---

## 28. Resultado do teste após as alterações

Depois da correção:

```text
Veículo corrigido → sincronizou ✅
Plataforma → sincronizou ✅
Ganho → sincronizou ✅
Jornada → sincronizou ✅
```

O comportamento foi validado com sucesso.

---

## 29. Logs de sincronização

Também foi mantida/recomendada a visualização de logs no `SyncManager`.

Formato esperado:

```text
[SYNC] entidade=ganho id=... status=ok codigo=null motivo=null
```

Em caso de erro:

```text
[SYNC] entidade=jornada status=erro codigo=NAO_ENCONTRADO motivo=Veículo não encontrado ou removido
```

Isso ajuda a diagnosticar rapidamente problemas futuros.

---

## 30. Arquivos modificados — resumo

### Backend

```text
backend/prisma/schema.prisma
backend/prisma/migrations/<migration>_placa_unica_por_usuario/migration.sql
backend/src/veiculos/veiculos.service.ts
backend/src/sincronizacao/sincronizacao.service.ts
```

### Mobile

```text
mobile/lib/features/sync/data/sync_local_repository.dart
mobile/lib/features/sync/services/sync_manager.dart
```

---

## 31. Arquivos analisados durante o diagnóstico

Também foram analisados:

```text
mobile/lib/features/sync/data/sync_repository.dart
mobile/lib/features/sync/data/sync_outbox_item.dart
mobile/lib/features/earnings/data/earning_repository.dart
mobile/lib/features/journeys/data/journey_repository.dart
backend/src/sincronizacao/sincronizacao.controller.ts
backend/src/sincronizacao/dto/enviar-sincronizacao.dto.ts
backend/prisma/schema.prisma
backend/src/veiculos/veiculos.service.ts
```

---

## 32. Regra final da placa

A regra consolidada ficou:

```text
Placa vazia
→ permitida

Mesmo usuário + mesma placa ativa
→ não permitido

Mesmo usuário + mesma placa inativa
→ não permitido; oferecer reativação

Usuários diferentes + mesma placa
→ permitido
```

---

## 33. Regra final da sincronização dependente

A regra consolidada ficou:

```text
Dependência inexistente
→ item dependente vai para atencao

Dependência corrigida e confirmada pelo servidor
→ item dependente volta para pendente

Nova tentativa
→ sincronização automática
```

---

## 34. Exemplo completo após a correção

```text
Conta A
→ cadastra ABC1D23
→ sincroniza ✅

Conta B
→ cadastra ABC1D23
→ sincroniza ✅

Conta B
→ lança ganho offline
→ salva localmente

Conta B
→ cria jornada offline
→ salva localmente

Conexão retorna
→ veículo confirmado
→ ganho sincroniza ✅
→ jornada sincroniza ✅
```

---

## 35. Teste de duplicidade na mesma conta

Cenário esperado:

```text
Conta B
→ veículo ABC1D23 já existe

Conta B
→ tenta cadastrar outro ABC1D23
```

Resultado:

```text
409 Conflict
Você já possui um veículo cadastrado com essa placa
```

Esse comportamento permanece protegido tanto no service quanto no banco.

---

## 36. Teste com veículo inativo

Cenário:

```text
Conta B
→ ABC1D23 está inativo
→ usuário tenta cadastrar novamente
```

Resultado esperado:

```text
409 Conflict
Você já tem um veículo removido com essa placa.
Reative-o na lista de inativos.
```

O backend retorna o ID do veículo inativo para permitir tratamento no aplicativo.

---

## 37. Impacto na arquitetura local-first

A correção reforçou uma característica importante da arquitetura.

No modo local-first:

```text
salvar localmente não significa que o backend já aceitou o dado
```

Isso é esperado.

O aplicativo precisa saber lidar com:

```text
conflito
validação
dependência
reprocessamento
```

A nova lógica faz isso de forma mais resiliente.

---

## 38. Por que o mobile deve permitir salvar offline

Não seria correto exigir que o mobile verificasse no servidor se uma placa já existe antes de permitir o cadastro.

Quando o motorista está offline:

```text
backend não está disponível
```

Logo:

```text
mobile salva
↓
marca como pendente
↓
servidor decide posteriormente
```

Esse comportamento foi mantido.

A correção foi feita no tratamento da sincronização, e não removendo a capacidade offline.

---

## 39. Integridade de dados preservada

A solução atual preserva:

- funcionamento offline;
- isolamento por usuário;
- integridade relacional;
- histórico de veículos;
- soft delete;
- unicidade por conta;
- recuperação automática de dependências;
- consistência entre API normal e RF11.

---

## 40. Comandos relacionados às alterações

Migration e Prisma:

```powershell
npx prisma format
npx prisma migrate dev --create-only --name placa_unica_por_usuario
npx prisma migrate dev
npx prisma generate
```

Backend:

```powershell
npm run start:dev
```

Mobile:

```powershell
flutter analyze
flutter run
```

---

## 41. Estado final da correção

| Item | Status |
|---|---|
| Diagnóstico da falha | Concluído |
| Placa única por usuário | Concluído |
| Mesma placa em usuários diferentes | Permitido |
| Mesma placa duplicada na mesma conta | Bloqueado |
| Veículo inativo duplicado | Tratado |
| Constraint global removida | Concluído |
| Índice parcial por usuário | Concluído |
| CRUD de veículos atualizado | Concluído |
| RF11 atualizado | Concluído |
| Reprocessamento de atenção | Concluído |
| Ganhos antigos recuperados | Validado |
| Jornadas antigas recuperadas | Validado |
| Veículo corrigido sincronizado | Validado |
| Plataforma sincronizada | Validado |
| Fluxo completo | Validado com sucesso |

---

## 42. Conclusão

A falha encontrada durante os testes não era um problema geral de conexão ou de sincronização.

O problema nasceu de uma combinação entre:

```text
regra de placa global
+
arquitetura local-first
+
dependências entre entidades
+
itens presos em estado atencao
```

A correção foi realizada em duas frentes.

Primeiro, a regra da placa foi alterada para refletir melhor o domínio do Route Cash:

```text
placa única por usuário
```

Segundo, o mecanismo de sincronização foi fortalecido para recuperar automaticamente lançamentos que falharam temporariamente porque uma dependência ainda não existia no servidor.

O resultado final é um fluxo mais consistente e resiliente:

```text
usuário trabalha offline
↓
dados ficam locais
↓
backend retorna eventuais conflitos
↓
usuário corrige a dependência
↓
dependência sincroniza
↓
lançamentos dependentes são recuperados
↓
sincronização termina sem perda de dados
```

A correção foi testada e considerada funcional em **13/11/2026**.

Com isso, o Route Cash passa a lidar corretamente com um cenário realista de uso offline envolvendo dependências entre veículos, ganhos e jornadas, mantendo a integridade dos dados sem exigir que o usuário refaça manualmente os lançamentos.
