import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const dia = (data: Date) => data.toISOString().slice(0, 10);

@Injectable()
export class PagamentosService {
  constructor(private readonly prisma: PrismaService) {}

  // HU40: histórico de pagamentos do próprio usuário, do mais recente para o mais antigo
  // (o mais recente é o primeiro da lista). Os pagamentos são registrados pelo administrador (RF18).
  async listar(usuarioId: string) {
    const pagamentos = await this.prisma.pagamento.findMany({
      where: { assinatura: { id_usuario: usuarioId } },
      include: {
        assinatura: { include: { plano: { select: { nome: true } } } },
      },
      orderBy: [{ data_vencimento: 'desc' }, { data_cadastro: 'desc' }],
    });

    return pagamentos.map((p) => ({
      id_pagamento: p.id_pagamento,
      id_assinatura: p.id_assinatura,
      plano_nome: p.assinatura.plano.nome,
      valor: Number(p.valor),
      data_vencimento: dia(p.data_vencimento),
      data_pagamento: p.data_pagamento ? dia(p.data_pagamento) : null,
      situacao: p.situacao,
    }));
  }
}