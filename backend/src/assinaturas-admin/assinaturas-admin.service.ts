import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, SituacaoAssinatura } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { hojeComoData } from '../common/periodo-cobranca';
import { ConsultarAssinaturasDto } from './dto/consultar-assinaturas.dto';

export type AssinaturaCompleta = Prisma.AssinaturaGetPayload<{
    include: {
        usuario: {
            select: { id_usuario: true; nome: true, email: true; status_conta: true};
        };
        plano: true;
    };
}>;

const INCLUIR_COMPLETO = {
    usuario: {
        select: { id_usuario: true, nome: true, email: true, status_conta: true},

    },
    plano: true,
} as const;

const dia = (data: Date) => data.toISOString().slice(0, 10);

// RF17: o administrador acompanha e controla as assinaturas. É um módulo SEPARADO do módulo
// do motorista (/assinaturas, RF13) e do módulo do Asaas: aqui só se lê e se muda a assinatura.
//
// Situações: PENDENTE (aguardando pagamento) | ATIVA | SUSPENSA | CANCELADA.
// Regras: suspender só de ATIVA; reativar só de SUSPENSA; cancelar de qualquer situação
// que não seja CANCELADA. Nada é apagado: a assinatura cancelada fica no histórico.
//
// ATENÇÃO (Asaas): para assinaturas com origem ASAAS que já têm checkout/assinatura no gateway,
// estas ações mudam só o Route Cash. O cancelamento/ajuste no Asaas ainda não existe no
// AsaasService (está na etapa do Webhook). Quando existir, deve ser chamado dentro de alterar(),
// antes de gravar. Por isso a resposta traz "vinculo_asaas", que a tela usa para avisar o admin.
@Injectable()
export class AssinaturasAdminService {
    constructor(private readonly prisma: PrismaService) {}

    private serializar(a: AssinaturaCompleta) {
        return {
            id_assinatura: a.id_assinatura,
            situacao: a.situacao, 
            origem: a.origem,
            // Assinatura pendente (aguardando o pagamento) ainda não tem datas 
            data_inicio: a.data_inicio ? dia(a.data_inicio) : null,
            data_vencimento: a.data_vencimento ? dia(a.data_vencimento) : null,
            vencida: 
            a.situacao !== SituacaoAssinatura.CANCELADA && 
            a.data_vencimento !== null && 
            a.data_vencimento.getTime() < hojeComoData().getTime(),
            data_cancelamento: a.data_cancelamento
            ? a.data_cancelamento.toISOString()
            : null, 
        data_cadastro: a.data_cadastro.toISOString(),
        veiculo_asaas: Boolean(a.asaas_subscription_id || a.asaas_checkout_id),
        usuario: {
            id_usuario: a.usuario.id_usuario,
            nome: a.usuario.nome, 
            email: a.usuario.email,
            status_conta: a.usuario.status_conta, 
}, 

        plano: {
            id_plano: a.plano.id_plano,
            nome: a.plano.nome,
            valor: Number(a.plano.valor),
            periodo_cobranca: a.plano.periodo_cobranca,
        },
    };
}

    private serializarDetalhe(a: AssinaturaCompleta) {
        return {
            ...this.serializar(a), 
            asaas_checkout_id: a.asaas_checkout_id, 
            asaas_subscription_id: a.asaas_subscription_id,
        };
    }

    private async obter(id: string) {
        const assinatura = await this.prisma.assinatura.findUnique({
            where: { id_assinatura: id }, 
            include: INCLUIR_COMPLETO,
        });
        if (!assinatura){
            throw new NotFoundException('Assinatura não foi encontrada'); 
        }
        return assinatura; 
    }

    // Listar, pesquisar (usuário ou plano) e filtrar por situação 
    async listar(filtro: ConsultarAssinaturasDto) {
    const pagina = filtro.pagina ?? 1;
    const limite = filtro.limite ?? 20;
    const busca = filtro.busca?.trim();

    const where: Prisma.AssinaturaWhereInput = {
      ...(filtro.situacao && { situacao: filtro.situacao }),
      ...(busca && {
        OR: [
          { usuario: { nome: { contains: busca, mode: 'insensitive' as const } } },
          { usuario: { email: { contains: busca, mode: 'insensitive' as const } } },
          { plano: { nome: { contains: busca, mode: 'insensitive' as const } } },
        ],
      }),
    };

    const [assinaturas, total] = await Promise.all([
      this.prisma.assinatura.findMany({
        where,
        include: INCLUIR_COMPLETO,
        orderBy: { data_cadastro: 'desc' },
        skip: (pagina - 1) * limite,
        take: limite,
      }),
      this.prisma.assinatura.count({ where }),
    ]);

    return {
      itens: assinaturas.map((a) => this.serializar(a)),
      total,
      pagina,
      limite,
    };
  }

  async buscarUm(id: string) {
    return this.serializarDetalhe(await this.obter(id));
  }

  private async alterar(id: string, dados: Prisma.AssinaturaUpdateInput) {
    // (futuro) sincronizar com o Asaas aqui, antes de gravar
    const atualizada = await this.prisma.assinatura.update({
      where: { id_assinatura: id },
      data: dados,
      include: INCLUIR_COMPLETO,
    });
    return this.serializarDetalhe(atualizada);
  }

  async suspender(id: string) {
    const assinatura = await this.obter(id);
    if (assinatura.situacao !== SituacaoAssinatura.ATIVA) {
      throw new BadRequestException('Somente assinaturas ativas podem ser suspensas');
    }
    return this.alterar(id, { situacao: SituacaoAssinatura.SUSPENSA });
  }

  async reativar(id: string) {
    const assinatura = await this.obter(id);
    if (assinatura.situacao !== SituacaoAssinatura.SUSPENSA) {
      throw new BadRequestException('Somente assinaturas suspensas podem ser reativadas');
    }

    // Reativar nunca pode deixar o usuário com duas assinaturas em aberto
    const outraEmAberto = await this.prisma.assinatura.findFirst({
      where: {
        id_usuario: assinatura.usuario.id_usuario,
        id_assinatura: { not: id },
        situacao: {
          in: [
            SituacaoAssinatura.PENDENTE,
            SituacaoAssinatura.ATIVA,
            SituacaoAssinatura.SUSPENSA,
          ],
        },
      },
    });
    if (outraEmAberto) {
      throw new ConflictException(
        'O usuário possui outra assinatura em aberto. Resolva-a antes de reativar esta',
      );
    }

    return this.alterar(id, { situacao: SituacaoAssinatura.ATIVA });
  }

  // Preserva o registro: só muda a situação e grava a data do cancelamento
  async cancelar(id: string) {
    const assinatura = await this.obter(id);
    if (assinatura.situacao === SituacaoAssinatura.CANCELADA) {
      throw new BadRequestException('A assinatura já está cancelada');
    }
    return this.alterar(id, {
      situacao: SituacaoAssinatura.CANCELADA,
      data_cancelamento: new Date(),
    });
  }
}