DROP INDEX IF EXISTS "veiculo_placa_key";

CREATE UNIQUE INDEX "veiculo_id_usuario_placa_key"
ON "veiculo" ("id_usuario", "placa")
WHERE "placa" IS NOT NULL;