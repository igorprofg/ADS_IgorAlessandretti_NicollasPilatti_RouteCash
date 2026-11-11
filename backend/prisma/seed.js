// SEED DE DESENVOLVIMENTO: planos FICTÍCIOS, só para testar o RF12 antes do cadastro
// de planos pelo administrador (RF16). Os valores e benefícios abaixo são dados de teste.
//
// - Rode manualmente: npx prisma db seed
// - Não duplica: só cria o plano se ainda não existir um com o mesmo nome.
// - Não roda em produção.
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

const PLANOS_DE_TESTE = [
  {
    nome: 'Plano Mensal',
    valor: 19.9,
    periodo_cobranca: 'MENSAL',
    beneficios: [
      'Dashboard financeiro completo',
      'Gráficos por período',
      'Sincronização entre aplicativo e web',
    ].join('\n'),
  },
  {
    nome: 'Plano Trimestral',
    valor: 49.9,
    periodo_cobranca: 'TRIMESTRAL',
    beneficios: [
      'Tudo do plano mensal',
      'Economia em relação ao mensal',
      'Histórico completo de lançamentos',
    ].join('\n'),
  },
  {
    nome: 'Plano Anual',
    valor: 179.9,
    periodo_cobranca: 'ANUAL',
    beneficios: [
      'Tudo do plano trimestral',
      'Melhor custo por mês',
      'Suporte prioritário',
    ].join('\n'),
  },
];

async function main() {
  if (process.env.NODE_ENV === 'production') {
    console.log('Seed de desenvolvimento ignorado em produção.');
    return;
  }

  for (const plano of PLANOS_DE_TESTE) {
    const existente = await prisma.plano.findFirst({ where: { nome: plano.nome } });
    if (existente) {
      console.log(`Plano já existe, mantido: ${plano.nome}`);
      continue;
    }
    await prisma.plano.create({ data: plano });
    console.log(`Plano de teste criado: ${plano.nome}`);
  }
}

main()
  .catch((erro) => {
    console.error(erro);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());