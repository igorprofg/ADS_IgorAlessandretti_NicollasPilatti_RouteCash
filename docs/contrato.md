# Contrato de sincronização (RF11) — RouteCash

Todas as rotas exigem `Authorization: Bearer <token>`.

## Regras gerais

| Regra | Detalhe |
|---|---|
| **UUID** | O app gera um UUID v4 para todo ganho, despesa e jornada (online ou offline). O servidor usa exatamente esse id. |
| **Escrita de lançamentos** | Ganho, despesa e jornada são gravados **sempre** por `POST /sincronizacao/enviar` (também com internet). As rotas `POST /ganhos`, `POST /despesas`, `POST /jornadas/...` não aceitam id do app e são usadas pela web. Leituras (`GET`) continuam normais. |
| **Cadastros** | **Veículo e plataforma** também podem ser criados e editados offline, e vão por `/sincronizacao/enviar` (ver a seção "Veículos e plataformas"). **Categoria** continua só online, pelas rotas REST normais, com cache no app. |
| **Horários** | Sempre em **UTC com sufixo Z**, ex.: `2026-10-20T18:30:00.000Z` (Dart: `DateTime.now().toUtc().toIso8601String()`). Sem fuso o servidor rejeita. |
| **Datas (sem hora)** | `AAAA-MM-DD`. |
| **Lote** | No máximo **50 itens por lista** (ganhos, despesas, jornadas, exclusões) por chamada. Se tiver mais, enviar em várias chamadas. |
| **Ordem** | Primeiro `enviar`, depois `baixar`. |

## POST /sincronizacao/enviar

Cada registro é o **estado completo** (não é diferença). Criar e editar são a mesma coisa para o servidor (upsert por id). Se o mesmo registro foi editado várias vezes offline, mande só o estado mais recente.

```json
{
  "ganhos": [
    {
      "id_ganho": "uuid-v4",
      "id_veiculo": "uuid",
      "id_plataforma": "uuid",
      "valor": 150.5,
      "data": "2026-10-20",
      "observacao": "gorjeta da corrida no mercado",
      "atualizado_em": "2026-10-20T18:30:00.000Z"
    }
  ],
  "despesas": [
    {
      "id_despesa": "uuid-v4",
      "id_veiculo": "uuid",
      "id_categoria": "uuid",
      "valor": 35,
      "data": "2026-10-20",
      "observacao": null,
      "atualizado_em": "2026-10-20T18:31:00.000Z"
    }
  ],
  "jornadas": [
    {
      "id_jornada": "uuid-v4",
      "id_veiculo": "uuid",
      "inicio": "2026-10-20T11:00:00.000Z",
      "fim": null,
      "km_rodados": null,
      "atualizado_em": "2026-10-20T11:00:00.000Z"
    }
  ],
  "exclusoes": [
    { "entidade": "ganho", "id": "uuid" }
  ]
}
```

- `fim: null` = jornada em andamento. `km_rodados: null` = sem quilometragem (remover o km = mandar a jornada com `km_rodados: null`).
- `observacao` é opcional (máx. 255).
- `entidade` da exclusão: `ganho`, `despesa` ou `jornada`.

### Resposta (HTTP 200)

Um resultado **por item**; um item com erro não impede os outros.

```json
{
  "sincronizado_em": "2026-10-20T18:32:10.000Z",
  "resultados": [
    { "entidade": "ganho", "id": "uuid", "status": "ok", "acao": "criado" },
    { "entidade": "despesa", "id": "uuid", "status": "ignorado", "codigo": "JA_SINCRONIZADO", "motivo": "..." },
    { "entidade": "jornada", "id": "uuid", "status": "erro", "codigo": "CONFLITO", "motivo": "Já existe uma jornada em andamento" }
  ]
}
```

| status | codigo | O que o app faz |
|---|---|---|
| `ok` (`acao`: criado, atualizado, excluido) | — | Tira da fila |
| `ignorado` | `JA_SINCRONIZADO` (já estava igual / já não existe no servidor) | Tira da fila |
| `ignorado` | `SERVIDOR_MAIS_RECENTE` (o servidor tem uma edição mais nova) | Tira da fila; o próximo `baixar` traz a versão do servidor |
| `erro` | `ERRO_INTERNO` | Mantém na fila e tenta de novo depois |
| `erro` | `VALIDACAO`, `NAO_ENCONTRADO`, `CONFLITO` | Mantém local, marca "precisa de atenção" e mostra o `motivo`; o usuário corrige ou descarta (não reenviar em loop) |

Casos que geram erro: valor ou km inválido, veículo/plataforma removidos ou inativos (`NAO_ENCONTRADO`), categoria que não é do usuário, jornada em andamento duplicada ou **horário sobreposto a outra jornada** (`CONFLITO`), fim anterior ao início, horário no futuro.

### Conflito de edição

Vence a alteração mais recente: o servidor compara `atualizado_em` (momento em que o usuário alterou no app) com a última alteração do registro no servidor. O app deve atualizar `atualizado_em` a cada edição local. O servidor limita `atualizado_em` ao horário atual dele (relógio do celular adiantado).

## GET /sincronizacao/baixar

Retrato completo do usuário (inclui veículos e plataformas **inativos**, com o campo `ativo`/`ativa`):

```json
{
  "sincronizado_em": "...",
  "veiculos": [], "plataformas": [], "categorias_despesa": [],
  "ganhos": [], "despesas": [], "jornadas": []
}
```

- Nesta resposta os valores decimais (`valor`, `consumo_medio`, `km_rodados`) vêm como **número**, e `data` de ganho/despesa como `AAAA-MM-DD`. Cada registro traz `data_atualizacao` (guardar como `atualizado_em` local).
- **Reconciliação no app:** atualizar/inserir o que veio; apagar localmente os registros já sincronizados que **não vieram** (foram excluídos na web); **nunca** apagar o que ainda está pendente na fila.
- Categorias vêm as padrão (`id_usuario` nulo) + as do usuário.

## Veículos e plataformas (atualização)

Mesma lógica dos lançamentos: estado completo, UUID v4 gerado no app, `atualizado_em` em UTC com Z, até 50 itens por lista. Novas listas no corpo do `POST /sincronizacao/enviar`: `veiculos` e `plataformas`.

**Ordem de processamento no servidor:** veículos, plataformas, ganhos, despesas, jornadas, exclusões. Assim um ganho pode referenciar um veículo ou plataforma criados offline no mesmo lote.

```json
{
  "veiculos": [
    {
      "id_veiculo": "uuid-v4",
      "marca": "Fiat",
      "modelo": "Argo",
      "ano": 2022,
      "combustivel": "Flex",
      "consumo_medio": 12.5,
      "placa": "ABC1D23",
      "ativo": true,
      "principal": true,
      "atualizado_em": "2026-10-28T18:30:00.000Z"
    }
  ],
  "plataformas": [
    {
      "id_plataforma": "uuid-v4",
      "nome": "Cabify",
      "ativa": true,
      "atualizado_em": "2026-10-28T18:31:00.000Z"
    }
  ]
}
```

| Campo | Regra |
|---|---|
| `marca`, `modelo` | Obrigatórios, até **50** caracteres |
| `combustivel` | Obrigatório, até 30 caracteres |
| `ano` | Inteiro entre 1950 e 2100 |
| `consumo_medio` | Maior que zero, até 999,99 (2 casas) |
| `placa` | Opcional (`null`), até 10 caracteres, **única no sistema** |
| Plataforma `nome` | Obrigatório, até **60** caracteres, único por usuário (sem diferenciar maiúsculas de minúsculas) |

**Regras**
- **Não há exclusão** de veículo nem de plataforma: excluir veículo = enviar `ativo: false`; inativar plataforma = enviar `ativa: false`. Não use `exclusoes` para eles.
- Veículo inativo nunca é o principal: o servidor grava `principal: false` se `ativo` for `false`. Só pode haver um principal por usuário; ao marcar um novo, o anterior perde a marca.
- Plataforma **padrão** (`padrao: true`, criada pelo servidor no cadastro) só aceita mudar `ativa`; o nome enviado é ignorado. O app não envia o campo `padrao` e não cria plataformas padrão.
- Placa já usada por outro veículo e nome de plataforma repetido retornam `erro` com `CONFLITO` (fica local, "precisa de atenção").
- Erros previsíveis do banco (valor longo demais, registro duplicado) nunca viram `ERRO_INTERNO`, para o app não reenviar em loop.