/*
  Warnings:

  - A unique constraint covering the columns `[asaas_checkout_id]` on the table `assinatura` will be added. If there are existing duplicate values, this will fail.
  - A unique constraint covering the columns `[asaas_subscription_id]` on the table `assinatura` will be added. If there are existing duplicate values, this will fail.
  - A unique constraint covering the columns `[asaas_payment_id]` on the table `pagamento` will be added. If there are existing duplicate values, this will fail.
  - A unique constraint covering the columns `[asaas_customer_id]` on the table `usuario` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateEnum
CREATE TYPE "OrigemAssinatura" AS ENUM ('MANUAL', 'ASAAS');

-- AlterEnum
ALTER TYPE "SituacaoAssinatura" ADD VALUE 'PENDENTE';

-- AlterTable
ALTER TABLE "assinatura" ADD COLUMN     "asaas_checkout_id" VARCHAR(100),
ADD COLUMN     "asaas_subscription_id" VARCHAR(100),
ADD COLUMN     "origem" "OrigemAssinatura" NOT NULL DEFAULT 'MANUAL',
ALTER COLUMN "data_inicio" DROP NOT NULL,
ALTER COLUMN "data_vencimento" DROP NOT NULL;

-- AlterTable
ALTER TABLE "pagamento" ADD COLUMN     "asaas_payment_id" VARCHAR(100);

-- AlterTable
ALTER TABLE "usuario" ADD COLUMN     "asaas_customer_id" VARCHAR(100);

-- CreateTable
CREATE TABLE "evento_webhook" (
    "id_evento" VARCHAR(150) NOT NULL,
    "provedor" VARCHAR(30) NOT NULL,
    "tipo" VARCHAR(100) NOT NULL,
    "processado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "evento_webhook_pkey" PRIMARY KEY ("id_evento")
);

-- CreateIndex
CREATE UNIQUE INDEX "assinatura_asaas_checkout_id_key" ON "assinatura"("asaas_checkout_id");

-- CreateIndex
CREATE UNIQUE INDEX "assinatura_asaas_subscription_id_key" ON "assinatura"("asaas_subscription_id");

-- CreateIndex
CREATE UNIQUE INDEX "pagamento_asaas_payment_id_key" ON "pagamento"("asaas_payment_id");

-- CreateIndex
CREATE UNIQUE INDEX "usuario_asaas_customer_id_key" ON "usuario"("asaas_customer_id");
