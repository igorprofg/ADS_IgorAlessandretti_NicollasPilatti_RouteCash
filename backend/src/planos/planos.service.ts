import { Injectable, NotFoundException } from '@nestjs/common';
import type { Plano } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AssinaturasService } from '../assinaturas/assinaturas.service';

@Injectable()
export class PlanosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly assinaturas: AssinaturasService,
  ) {}

  private serializar(
    plano: Plano,
    idPlanoContratado: string | null,
    temAssinaturaEmAberto: boolean,
  ) {
    return {
      id_plano: plano.id_plano,
      nome: plano.nome,
      valor: Number(plano.valor),
      periodo_cobranca: plano.periodo_cobranca,
      beneficios: plano.beneficios,
      ativo: plano.ativo,
      contratado: plano.id_plano === idPlanoContratado,
      // HU36: disponível = plano ativo e usuário sem assinatura em aberto (regra da HU37)
      disponivel_para_contratacao: plano.ativo && !temAssinaturaEmAberto,
    };
  }

  // HU35: só planos ativos, com o plano atualmente contratado identificado
  async listar(usuarioId: string) {
    const [planos, assinatura] = await Promise.all([
      this.prisma.plano.findMany({
        where: { ativo: true },
        orderBy: { valor: 'asc' },
      }),
      this.assinaturas.buscarEmAberto(usuarioId),
    ]);

    return planos.map((plano) =>
      this.serializar(plano, assinatura?.id_plano ?? null, assinatura !== null),
    );
  }

  // HU36: detalhes de um plano. Plano inativo só aparece para quem já teve assinatura nele.
  async buscarUm(usuarioId: string, id: string) {
    const [plano, assinatura] = await Promise.all([
      this.prisma.plano.findFirst({
        where: {
          id_plano: id,
          OR: [{ ativo: true }, { assinaturas: { some: { id_usuario: usuarioId } } }],
        },
      }),
      this.assinaturas.buscarEmAberto(usuarioId),
    ]);

    if (!plano) {
      throw new NotFoundException('Plano não encontrado');
    }
    return this.serializar(plano, assinatura?.id_plano ?? null, assinatura !== null);
  }
}