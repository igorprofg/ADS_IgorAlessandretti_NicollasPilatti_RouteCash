-- Evolução não destrutiva da tabela de idempotência para inbox durável.
-- NÃO executar prisma migrate reset. Executar uma vez via migrate deploy/dev.
ALTER TABLE "evento_webhook"
  ADD COLUMN "payload" JSONB,
  ADD COLUMN "situacao" VARCHAR(30) NOT NULL DEFAULT 'PENDENTE',
  ADD COLUMN "tentativas" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "erro" TEXT,
  ADD COLUMN "recebido_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN "ultima_tentativa_em" TIMESTAMP(3),
  ADD COLUMN "proxima_tentativa_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN "bloqueado_ate" TIMESTAMP(3);

-- Eventos de antes desta migration não têm corpo original; já estavam
-- marcados como processados pelo fluxo antigo. Não reprocessá-los sem payload.
UPDATE "evento_webhook"
SET "situacao" = 'PROCESSADO',
    "payload" = jsonb_build_object('id', "id_evento", 'event', "tipo")
WHERE "payload" IS NULL;
ALTER TABLE "evento_webhook" ALTER COLUMN "payload" SET NOT NULL;
ALTER TABLE "evento_webhook" ALTER COLUMN "processado_em" DROP NOT NULL;
ALTER TABLE "evento_webhook" ALTER COLUMN "processado_em" DROP DEFAULT;
CREATE INDEX "evento_webhook_situacao_proxima_tentativa_em_idx"
  ON "evento_webhook"("situacao", "proxima_tentativa_em");
