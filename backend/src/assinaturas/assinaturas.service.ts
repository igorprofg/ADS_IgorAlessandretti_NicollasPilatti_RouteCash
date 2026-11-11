import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Prisma, SituacaoAssinatura } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  adicionarMeses,
  hojeComoData,
  mesesDoPeriodo,
} from '../common/periodo-cobranca';
import { ContratarAssinaturaDto } from './dto/contratar-assinatura.dto';

export type AssinaturaComPlano = Prisma.AssinaturaGetPayload<{
  include: { plano: true };
}>;

// Assinatura "em aberto" = ativa ou suspensa. A suspensa também conta porque o administrador
// pode reativá-la (RF17/HU50); se o motorista contratasse outro plano nesse meio tempo,
// a reativação criaria duas assinaturas ativas ao mesmo tempo, o que a HU37 proíbe.
const SITUACOES_EM_ABERTO = [SituacaoAssinatura.ATIVA, SituacaoAssinatura.SUSPENSA];

const dia = (data: Date) => data.toISOString().slice(0, 10);

@Injectable()
export class AssinaturasService {
  constructor(private readonly prisma: PrismaService) {}

  // Também usada pelo módulo de planos para identificar o plano contratado
  async buscarEmAberto(usuarioId: string): Promise<AssinaturaComPlano | null> {
    return this.prisma.assinatura.findFirst({
      where: { id_usuario: usuarioId, situacao: { in: SITUACOES_EM_ABERTO } },
      include: { plano: true },
      orderBy: { data_cadastro: 'desc' },
    });
  }

  private serializar(a: AssinaturaComPlano) {
    const emAberto = a.situacao !== SituacaoAssinatura.CANCELADA;
    return {
      id_assinatura: a.id_assinatura,
      situacao: a.situacao,
      data_inicio: dia(a.data_inicio),
      data_vencimento: dia(a.data_vencimento),
      data_cancelamento: a.data_cancelamento
        ? a.data_cancelamento.toISOString()
        : null,
      // Campo calculado: a situação gravada não muda sozinha quando o vencimento passa
      vencida: emAberto && a.data_vencimento.getTime() < hojeComoData().getTime(),
      plano: {
        id_plano: a.plano.id_plano,
        nome: a.plano.nome,
        valor: Number(a.plano.valor),
        periodo_cobranca: a.plano.periodo_cobranca,
        beneficios: a.plano.beneficios,
      },
    };
  }

  // HU37: contratar plano (não gera pagamento: pagamentos são registrados pelo administrador, HU52)
  async contratar(usuarioId: string, dto: ContratarAssinaturaDto) {
    const plano = await this.prisma.plano.findUnique({
      where: { id_plano: dto.id_plano },
    });
    if (!plano) {
      throw new NotFoundException('Plano não encontrado');
    }
    if (!plano.ativo) {
      throw new BadRequestException('Este plano não está disponível para contratação');
    }

    const aberta = await this.buscarEmAberto(usuarioId);
    if (aberta) {
      const situacao =
        aberta.situacao === SituacaoAssinatura.SUSPENSA ? 'suspensa' : 'ativa';
      throw new ConflictException(
        `Você já possui uma assinatura ${situacao}. Cancele-a antes de contratar outro plano`,
      );
    }

    const meses = mesesDoPeriodo(plano.periodo_cobranca);
    if (meses === null) {
      throw new UnprocessableEntityException(
        'Este plano está com o período de cobrança inválido. Entre em contato com o suporte',
      );
    }

    const inicio = hojeComoData();
    try {
      const criada = await this.prisma.assinatura.create({
        data: {
          id_usuario: usuarioId,
          id_plano: plano.id_plano,
          data_inicio: inicio,
          data_vencimento: adicionarMeses(inicio, meses),
          situacao: SituacaoAssinatura.ATIVA,
        },
        include: { plano: true },
      });
      return this.serializar(criada);
    } catch (error) {
      // Só acontece se existir um índice único de assinatura em aberto e duas requisições chegarem juntas
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('Você já possui uma assinatura em aberto');
      }
      throw error;
    }
  }

  // HU38: assinatura atual do usuário
  async buscarAtual(usuarioId: string) {
    const atual = await this.buscarEmAberto(usuarioId);
    if (!atual) {
      throw new NotFoundException('Você não possui assinatura ativa');
    }
    return this.serializar(atual);
  }

  // Histórico próprio (inclui as canceladas, que são mantidas - HU39)
  async listar(usuarioId: string) {
    const assinaturas = await this.prisma.assinatura.findMany({
      where: { id_usuario: usuarioId },
      include: { plano: true },
      orderBy: { data_cadastro: 'desc' },
    });
    return assinaturas.map((a) => this.serializar(a));
  }

  // HU39: cancelar. Muda a situação e preserva o registro (não apaga nada).
  // A confirmação do usuário é feita na tela.
  async cancelarAtual(usuarioId: string) {
    const atual = await this.buscarEmAberto(usuarioId);
    if (!atual) {
      throw new NotFoundException('Você não possui assinatura para cancelar');
    }

    const cancelada = await this.prisma.assinatura.update({
      where: { id_assinatura: atual.id_assinatura },
      data: {
        situacao: SituacaoAssinatura.CANCELADA,
        data_cancelamento: new Date(),
      },
      include: { plano: true },
    });
    return this.serializar(cancelada);
  }
}