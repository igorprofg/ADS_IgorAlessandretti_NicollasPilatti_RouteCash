-- CreateEnum
CREATE TYPE "TipoUsuario" AS ENUM ('MOTORISTA', 'ADMINISTRADOR');

-- CreateEnum
CREATE TYPE "StatusConta" AS ENUM ('ATIVO', 'SUSPENSO', 'BLOQUEADO');

-- CreateEnum
CREATE TYPE "SituacaoAssinatura" AS ENUM ('ATIVA', 'SUSPENSA', 'CANCELADA');

-- CreateEnum
CREATE TYPE "SituacaoPagamento" AS ENUM ('PAGO', 'PENDENTE', 'VENCIDO');

-- CreateTable
CREATE TABLE "usuario" (
    "id_usuario" UUID NOT NULL,
    "nome" VARCHAR(100) NOT NULL,
    "email" VARCHAR(150) NOT NULL,
    "senha_hash" VARCHAR(255) NOT NULL,
    "tipo_usuario" "TipoUsuario" NOT NULL,
    "status_conta" "StatusConta" NOT NULL DEFAULT 'ATIVO',
    "aceite_termos_em" TIMESTAMP(3) NOT NULL,
    "data_cadastro" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "data_atualizacao" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "usuario_pkey" PRIMARY KEY ("id_usuario")
);

-- CreateTable
CREATE TABLE "veiculo" (
    "id_veiculo" UUID NOT NULL,
    "id_usuario" UUID NOT NULL,
    "marca" VARCHAR(50) NOT NULL,
    "modelo" VARCHAR(50) NOT NULL,
    "ano" INTEGER NOT NULL,
    "combustivel" VARCHAR(30) NOT NULL,
    "consumo_medio" DECIMAL(6,2) NOT NULL,
    "placa" VARCHAR(10),
    "principal" BOOLEAN NOT NULL DEFAULT false,
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "data_cadastro" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "data_atualizacao" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "veiculo_pkey" PRIMARY KEY ("id_veiculo")
);

-- CreateTable
CREATE TABLE "plataforma" (
    "id_plataforma" UUID NOT NULL,
    "id_usuario" UUID NOT NULL,
    "nome" VARCHAR(60) NOT NULL,
    "padrao" BOOLEAN NOT NULL DEFAULT false,
    "ativa" BOOLEAN NOT NULL DEFAULT true,
    "data_cadastro" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "data_atualizacao" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "plataforma_pkey" PRIMARY KEY ("id_plataforma")
);

-- CreateTable
CREATE TABLE "categoria_despesa" (
    "id_categoria" UUID NOT NULL,
    "id_usuario" UUID,
    "nome" VARCHAR(50) NOT NULL,
    "data_cadastro" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "data_atualizacao" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "categoria_despesa_pkey" PRIMARY KEY ("id_categoria")
);

-- CreateTable
CREATE TABLE "ganho" (
    "id_ganho" UUID NOT NULL,
    "id_veiculo" UUID NOT NULL,
    "id_plataforma" UUID NOT NULL,
    "valor" DECIMAL(12,2) NOT NULL,
    "data" DATE NOT NULL,
    "data_cadastro" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "data_atualizacao" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ganho_pkey" PRIMARY KEY ("id_ganho")
);

-- CreateTable
CREATE TABLE "despesa" (
    "id_despesa" UUID NOT NULL,
    "id_veiculo" UUID NOT NULL,
    "id_categoria" UUID NOT NULL,
    "valor" DECIMAL(12,2) NOT NULL,
    "data" DATE NOT NULL,
    "data_cadastro" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "data_atualizacao" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "despesa_pkey" PRIMARY KEY ("id_despesa")
);

-- CreateTable
CREATE TABLE "jornada" (
    "id_jornada" UUID NOT NULL,
    "id_usuario" UUID NOT NULL,
    "id_veiculo" UUID NOT NULL,
    "inicio" TIMESTAMP(3) NOT NULL,
    "fim" TIMESTAMP(3),
    "km_rodados" DECIMAL(8,2),
    "data_cadastro" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "data_atualizacao" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "jornada_pkey" PRIMARY KEY ("id_jornada")
);

-- CreateTable
CREATE TABLE "plano" (
    "id_plano" UUID NOT NULL,
    "nome" VARCHAR(60) NOT NULL,
    "valor" DECIMAL(12,2) NOT NULL,
    "periodo_cobranca" VARCHAR(30) NOT NULL,
    "beneficios" TEXT NOT NULL,
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "data_cadastro" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "data_atualizacao" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "plano_pkey" PRIMARY KEY ("id_plano")
);

-- CreateTable
CREATE TABLE "assinatura" (
    "id_assinatura" UUID NOT NULL,
    "id_usuario" UUID NOT NULL,
    "id_plano" UUID NOT NULL,
    "data_inicio" DATE NOT NULL,
    "data_vencimento" DATE NOT NULL,
    "situacao" "SituacaoAssinatura" NOT NULL DEFAULT 'ATIVA',
    "data_cancelamento" TIMESTAMP(3),
    "data_cadastro" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "data_atualizacao" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "assinatura_pkey" PRIMARY KEY ("id_assinatura")
);

-- CreateTable
CREATE TABLE "pagamento" (
    "id_pagamento" UUID NOT NULL,
    "id_assinatura" UUID NOT NULL,
    "valor" DECIMAL(12,2) NOT NULL,
    "data_vencimento" DATE NOT NULL,
    "data_pagamento" DATE,
    "situacao" "SituacaoPagamento" NOT NULL DEFAULT 'PENDENTE',
    "data_cadastro" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "data_atualizacao" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "pagamento_pkey" PRIMARY KEY ("id_pagamento")
);

-- CreateIndex
CREATE UNIQUE INDEX "usuario_email_key" ON "usuario"("email");

-- CreateIndex
CREATE UNIQUE INDEX "veiculo_placa_key" ON "veiculo"("placa");

-- CreateIndex
CREATE UNIQUE INDEX "plataforma_nome_id_usuario_key" ON "plataforma"("nome", "id_usuario");

-- CreateIndex
CREATE UNIQUE INDEX "categoria_despesa_nome_id_usuario_key" ON "categoria_despesa"("nome", "id_usuario");

CREATE UNIQUE INDEX categoria_padrao_nome_unique ON categoria_despesa (nome) WHERE id_usuario IS NULL;

-- AddForeignKey
ALTER TABLE "veiculo" ADD CONSTRAINT "veiculo_id_usuario_fkey" FOREIGN KEY ("id_usuario") REFERENCES "usuario"("id_usuario") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "plataforma" ADD CONSTRAINT "plataforma_id_usuario_fkey" FOREIGN KEY ("id_usuario") REFERENCES "usuario"("id_usuario") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "categoria_despesa" ADD CONSTRAINT "categoria_despesa_id_usuario_fkey" FOREIGN KEY ("id_usuario") REFERENCES "usuario"("id_usuario") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ganho" ADD CONSTRAINT "ganho_id_veiculo_fkey" FOREIGN KEY ("id_veiculo") REFERENCES "veiculo"("id_veiculo") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ganho" ADD CONSTRAINT "ganho_id_plataforma_fkey" FOREIGN KEY ("id_plataforma") REFERENCES "plataforma"("id_plataforma") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "despesa" ADD CONSTRAINT "despesa_id_veiculo_fkey" FOREIGN KEY ("id_veiculo") REFERENCES "veiculo"("id_veiculo") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "despesa" ADD CONSTRAINT "despesa_id_categoria_fkey" FOREIGN KEY ("id_categoria") REFERENCES "categoria_despesa"("id_categoria") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "jornada" ADD CONSTRAINT "jornada_id_usuario_fkey" FOREIGN KEY ("id_usuario") REFERENCES "usuario"("id_usuario") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "jornada" ADD CONSTRAINT "jornada_id_veiculo_fkey" FOREIGN KEY ("id_veiculo") REFERENCES "veiculo"("id_veiculo") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assinatura" ADD CONSTRAINT "assinatura_id_usuario_fkey" FOREIGN KEY ("id_usuario") REFERENCES "usuario"("id_usuario") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assinatura" ADD CONSTRAINT "assinatura_id_plano_fkey" FOREIGN KEY ("id_plano") REFERENCES "plano"("id_plano") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pagamento" ADD CONSTRAINT "pagamento_id_assinatura_fkey" FOREIGN KEY ("id_assinatura") REFERENCES "assinatura"("id_assinatura") ON DELETE RESTRICT ON UPDATE CASCADE;
