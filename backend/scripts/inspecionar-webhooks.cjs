// Execute: node scripts/inspecionar-webhooks.cjs
// Somente leitura. Nunca exibe o payload integral nem informações de cartão.
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
(async () => {
  const contagens = await prisma.eventoWebhook.groupBy({
    by: ['situacao'], _count: { _all: true },
  });
  console.table(contagens.map(x => ({ situacao: x.situacao, quantidade: x._count._all })));
  const eventos = await prisma.eventoWebhook.findMany({
    where: { situacao: { in: ['RECONCILIACAO', 'PENDENTE'] } },
    select: { id_evento: true, tipo: true, situacao: true, tentativas: true,
      erro: true, recebido_em: true },
    orderBy: { recebido_em: 'desc' }, take: 25,
  });
  console.table(eventos);
})().catch(e => { console.error(e); process.exitCode = 1; })
  .finally(() => prisma.$disconnect());
