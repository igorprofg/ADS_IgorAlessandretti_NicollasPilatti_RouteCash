// SEED DE DESENVOLVIMENTO. Tudo aqui é dado FICTÍCIO de teste:
//  - planos de exemplo, para testar o RF12 antes do cadastro de planos pelo administrador (RF16);
//  - um usuário administrador, porque não existe rota para criar administradores
//    (o cadastro pela API cria só motoristas).
//
// - Rode manualmente: npx prisma db seed
// - Não duplica: só cria o que ainda não existe.
// - Não roda em produção.
const bcrypt = require('bcrypt');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

const ADMIN_DE_TESTE = {
  nome: 'Administrador RouteCash',
  email: 'admin@routecash.com',
  // Troque a senha definindo ADMIN_SENHA_INICIAL no .env antes de rodar o seed
  senha: process.env.ADMIN_SENHA_INICIAL || 'Admin@12345',
};

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

async function criarPlanos() {
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

async function criarAdministrador() {
  const existente = await prisma.usuario.findUnique({
    where: { email: ADMIN_DE_TESTE.email },
  });
  if (existente) {
    console.log(`Administrador já existe, mantido: ${ADMIN_DE_TESTE.email}`);
    return;
  }

  await prisma.usuario.create({
    data: {
      nome: ADMIN_DE_TESTE.nome,
      email: ADMIN_DE_TESTE.email,
      senha_hash: await bcrypt.hash(ADMIN_DE_TESTE.senha, 10),
      tipo_usuario: 'ADMINISTRADOR',
      aceite_termos_em: new Date(),
    },
  });
  console.log(`Administrador de teste criado: ${ADMIN_DE_TESTE.email}`);
}

async function main() {
  if (process.env.NODE_ENV === 'production') {
    console.log('Seed de desenvolvimento ignorado em produção.');
    return;
  }

  await criarPlanos();
  await criarAdministrador();
}

main()
  .catch((erro) => {
    console.error(erro);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());