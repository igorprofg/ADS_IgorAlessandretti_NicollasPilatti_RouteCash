-- AlterTable
ALTER TABLE "assinatura" ALTER COLUMN "situacao" SET DEFAULT 'PENDENTE';

-- AlterTable
ALTER TABLE "usuario" ADD COLUMN     "bairro" VARCHAR(100),
ADD COLUMN     "cep" VARCHAR(8),
ADD COLUMN     "complemento" VARCHAR(100),
ADD COLUMN     "logradouro" VARCHAR(150),
ADD COLUMN     "numero_endereco" VARCHAR(20);
