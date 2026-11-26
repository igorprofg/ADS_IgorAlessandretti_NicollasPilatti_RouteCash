// Uso: node scripts/reprocessar-webhook.cjs "evt_..."
// ATENÇÃO: somente após corrigir a origem da falha e validar os vínculos.
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
(async () => {
  const id = process.argv[2];
  if (!id || !id.startsWith('evt_')) throw new Error('Informe o id_evento completo, entre aspas.');
  const atual = await prisma.eventoWebhook.findUnique({where: {id_evento: id}});
  if (!atual) throw new Error('Evento não encontrado na inbox.');
  if (atual.situacao !== 'RECONCILIACAO') throw new Error(`Evento ${atual.situacao}; somente RECONCILIACAO pode ser reenfileirado.`);
  const resultado = await prisma.eventoWebhook.updateMany({
    where: {id_evento: id, situacao: 'RECONCILIACAO'},
    data: {situacao: 'PENDENTE', tentativas: 0, erro: null, proxima_tentativa_em: new Date()},
  });
  console.log(resultado.count === 1 ? 'Evento reenfileirado; worker vai processar.' : 'Não houve alteração.');
})().catch(e => { console.error(e.message); process.exitCode = 1; })
  .finally(() => prisma.$disconnect());
