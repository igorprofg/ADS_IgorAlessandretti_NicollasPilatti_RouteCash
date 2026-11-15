/*
  Warnings:

  - A unique constraint covering the columns `[cpf_cnpj]` on the table `usuario` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE "usuario" ADD COLUMN     "celular" VARCHAR(20),
ADD COLUMN     "cpf_cnpj" VARCHAR(14);

-- CreateIndex
CREATE UNIQUE INDEX "usuario_cpf_cnpj_key" ON "usuario"("cpf_cnpj");
