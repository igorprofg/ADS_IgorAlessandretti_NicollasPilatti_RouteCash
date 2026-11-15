import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';

import {
  OrigemAssinatura,
  Prisma,
  SituacaoAssinatura,
} from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { AsaasService } from '../asaas/asaas.service';

import {
  adicionarMeses,
  hojeComoData,
  mesesDoPeriodo,
} from '../common/periodo-cobranca';

import { ContratarAssinaturaDto } from './dto/contratar-assinatura.dto';

// ============================================
// TIPO - ASSINATURA COM PLANO
// ============================================

export type AssinaturaComPlano =
  Prisma.AssinaturaGetPayload<{
    include: {
      plano: true;
    };
  }>;

// ============================================
// SITUAÇÕES EM ABERTO
// ============================================
//
// Uma assinatura é considerada "em aberto" quando:
//
// PENDENTE:
// criada, mas ainda aguardando pagamento/confirmação.
//
// ATIVA:
// acesso liberado normalmente.
//
// SUSPENSA:
// continua existindo e pode ser reativada.
//
// CANCELADA:
// não é considerada em aberto.
//
// PENDENTE também entra na validação para impedir
// que o mesmo usuário crie vários checkouts ao mesmo
// tempo.
//
const SITUACOES_EM_ABERTO: SituacaoAssinatura[] = [
  SituacaoAssinatura.PENDENTE,
  SituacaoAssinatura.ATIVA,
  SituacaoAssinatura.SUSPENSA,
];

// ============================================
// FORMATAÇÃO DE DATA
// ============================================
//
// data_inicio e data_vencimento podem ser null,
// principalmente enquanto uma assinatura Asaas
// estiver aguardando pagamento.
//
const dia = (data: Date | null): string | null => {
  if (!data) {
    return null;
  }

  return data.toISOString().slice(0, 10);
};

@Injectable()
export class AssinaturasService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly asaasService: AsaasService,
  ) {}

  // ============================================
  // BUSCAR ASSINATURA EM ABERTO
  // ============================================
  //
  // Considera:
  //
  // - PENDENTE
  // - ATIVA
  // - SUSPENSA
  //
  // Também pode ser utilizado por outros módulos
  // para verificar se o usuário já possui plano.
  //
  async buscarEmAberto(
    usuarioId: string,
  ): Promise<AssinaturaComPlano | null> {
    return this.prisma.assinatura.findFirst({
      where: {
        id_usuario: usuarioId,

        situacao: {
          in: SITUACOES_EM_ABERTO,
        },
      },

      include: {
        plano: true,
      },

      orderBy: {
        data_cadastro: 'desc',
      },
    });
  }

  // ============================================
  // SERIALIZAÇÃO
  // ============================================

  private serializar(a: AssinaturaComPlano) {
    const emAberto =
      a.situacao !== SituacaoAssinatura.CANCELADA;

    const vencida =
      emAberto &&
      a.data_vencimento !== null &&
      a.data_vencimento.getTime() <
        hojeComoData().getTime();

    return {
      id_assinatura: a.id_assinatura,

      id_usuario: a.id_usuario,

      situacao: a.situacao,

      // MANUAL ou ASAAS
      origem: a.origem,

      data_inicio: dia(a.data_inicio),

      data_vencimento: dia(a.data_vencimento),

      data_cancelamento: a.data_cancelamento
        ? a.data_cancelamento.toISOString()
        : null,

      // Assinaturas pendentes normalmente ainda
      // não possuem vencimento.
      vencida,

      // ========================================
      // ASAAS
      // ========================================

      asaas_checkout_id:
        a.asaas_checkout_id,

      asaas_subscription_id:
        a.asaas_subscription_id,

      // ========================================
      // PLANO
      // ========================================

      plano: {
        id_plano: a.plano.id_plano,
        nome: a.plano.nome,
        valor: Number(a.plano.valor),
        periodo_cobranca:
          a.plano.periodo_cobranca,
        beneficios:
          a.plano.beneficios,
      },
    };
  }

  // ============================================
  // HU37 - CONTRATAÇÃO MANUAL
  // ============================================
  //
  // Mantém o funcionamento antigo do Route Cash.
  //
  // Neste fluxo:
  //
  // - assinatura é criada imediatamente;
  // - situação = ATIVA;
  // - origem = MANUAL;
  // - datas são preenchidas imediatamente;
  // - não existe Checkout Asaas.
  //
  async contratar(
    usuarioId: string,
    dto: ContratarAssinaturaDto,
  ) {
    const plano =
      await this.prisma.plano.findUnique({
        where: {
          id_plano: dto.id_plano,
        },
      });

    if (!plano) {
      throw new NotFoundException(
        'Plano não encontrado',
      );
    }

    if (!plano.ativo) {
      throw new BadRequestException(
        'Este plano não está disponível para contratação',
      );
    }

    const aberta =
      await this.buscarEmAberto(usuarioId);

    if (aberta) {
      let situacao = 'em aberto';

      if (
        aberta.situacao ===
        SituacaoAssinatura.ATIVA
      ) {
        situacao = 'ativa';
      }

      if (
        aberta.situacao ===
        SituacaoAssinatura.SUSPENSA
      ) {
        situacao = 'suspensa';
      }

      if (
        aberta.situacao ===
        SituacaoAssinatura.PENDENTE
      ) {
        situacao = 'pendente';
      }

      throw new ConflictException(
        `Você já possui uma assinatura ${situacao}. Cancele-a antes de contratar outro plano`,
      );
    }

    const meses = mesesDoPeriodo(
      plano.periodo_cobranca,
    );

    if (meses === null) {
      throw new UnprocessableEntityException(
        'Este plano está com o período de cobrança inválido. Entre em contato com o suporte',
      );
    }

    const inicio = hojeComoData();

    try {
      const criada =
        await this.prisma.assinatura.create({
          data: {
            id_usuario: usuarioId,

            id_plano:
              plano.id_plano,

            data_inicio:
              inicio,

            data_vencimento:
              adicionarMeses(
                inicio,
                meses,
              ),

            // Fluxo manual libera imediatamente.
            situacao:
              SituacaoAssinatura.ATIVA,

            origem:
              OrigemAssinatura.MANUAL,
          },

          include: {
            plano: true,
          },
        });

      return this.serializar(criada);
    } catch (error) {
      if (
        error instanceof
          Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException(
          'Você já possui uma assinatura em aberto',
        );
      }

      throw error;
    }
  }

  // ============================================
  // CONTRATAÇÃO VIA ASAAS
  // ============================================
  //
  // Fluxo:
  //
  // usuário seleciona plano
  //        ↓
  // verificar assinatura existente
  //        ↓
  // obter/criar Customer no Asaas
  //        ↓
  // criar assinatura local PENDENTE
  //        ↓
  // criar Checkout Asaas
  //        ↓
  // salvar asaas_checkout_id
  //        ↓
  // retornar checkout_url
  //
  // IMPORTANTE:
  //
  // A assinatura NÃO fica ATIVA aqui.
  //
  // Ela continuará PENDENTE até o Webhook
  // confirmar o pagamento.
  //
  async contratarComAsaas(
    usuarioId: string,
    dto: ContratarAssinaturaDto,
  ) {
    // ==========================================
    // 1. BUSCAR PLANO
    // ==========================================

    const plano =
      await this.prisma.plano.findUnique({
        where: {
          id_plano: dto.id_plano,
        },
      });

    if (!plano) {
      throw new NotFoundException(
        'Plano não encontrado',
      );
    }

    if (!plano.ativo) {
      throw new BadRequestException(
        'Este plano não está disponível para contratação',
      );
    }

    // Valida também o período antes de criar
    // qualquer registro local.
    const meses = mesesDoPeriodo(
      plano.periodo_cobranca,
    );

    if (meses === null) {
      throw new UnprocessableEntityException(
        'Este plano está com o período de cobrança inválido. Entre em contato com o suporte',
      );
    }

    // ==========================================
    // 2. VERIFICAR ASSINATURA EM ABERTO
    // ==========================================

    const aberta =
      await this.buscarEmAberto(usuarioId);

    if (aberta) {
      // ----------------------------------------
      // PENDENTE ASAAS + CHECKOUT EXISTENTE
      // ----------------------------------------
      //
      // O usuário pode ter clicado duas vezes
      // em "Assinar".
      //
      // Se já temos um Checkout, não criamos outro.
      //

      if (
        aberta.situacao ===
          SituacaoAssinatura.PENDENTE &&
        aberta.origem ===
          OrigemAssinatura.ASAAS &&
        aberta.asaas_checkout_id
      ) {
        // Se o usuário está tentando contratar
        // outro plano enquanto existe Checkout
        // pendente, não reutilizamos silenciosamente.
        if (
          aberta.id_plano !==
          plano.id_plano
        ) {
          throw new ConflictException(
            'Você já possui uma contratação pendente para outro plano. Cancele a contratação atual antes de escolher outro plano.',
          );
        }

        return {
          assinatura:
            this.serializar(aberta),

          checkout_id:
            aberta.asaas_checkout_id,

          checkout_url:
            `https://asaas.com/checkoutSession/show?id=${aberta.asaas_checkout_id}`,

          checkout_reutilizado: true,
        };
      }

      // ----------------------------------------
      // PENDENTE ASAAS SEM CHECKOUT
      // ----------------------------------------
      //
      // Pode acontecer se:
      //
      // 1. assinatura local foi criada;
      // 2. chamada ao Asaas falhou;
      // 3. checkout_id não chegou a ser salvo.
      //
      // Nesse caso permitimos tentar novamente,
      // desde que seja o MESMO plano.
      //

      if (
        aberta.situacao ===
          SituacaoAssinatura.PENDENTE &&
        aberta.origem ===
          OrigemAssinatura.ASAAS &&
        !aberta.asaas_checkout_id
      ) {
        if (
          aberta.id_plano !==
          plano.id_plano
        ) {
          throw new ConflictException(
            'Você já possui uma contratação pendente para outro plano.',
          );
        }
      } else {
        // Qualquer assinatura ATIVA,
        // SUSPENSA ou fluxo MANUAL bloqueia
        // nova contratação.
        throw new ConflictException(
          'Você já possui uma assinatura em aberto.',
        );
      }
    }

    // ==========================================
    // 3. CUSTOMER ASAAS
    // ==========================================
    //
    // Se já existir:
    // reutiliza.
    //
    // Se ainda não existir:
    // cria no Asaas e salva asaas_customer_id.
    //

    const customer =
      await this.asaasService.obterOuCriarCliente(
        usuarioId,
      );

    // ==========================================
    // 4. ASSINATURA LOCAL
    // ==========================================

    let assinatura = aberta;

    if (!assinatura) {
      assinatura =
        await this.prisma.assinatura.create({
          data: {
            id_usuario:
              usuarioId,

            id_plano:
              plano.id_plano,

            // ==================================
            // ASAAS
            // ==================================
            //
            // Ainda não houve confirmação
            // de pagamento.
            //
            situacao:
              SituacaoAssinatura.PENDENTE,

            origem:
              OrigemAssinatura.ASAAS,

            // Somente serão preenchidas quando
            // o pagamento for confirmado.
            data_inicio: null,

            data_vencimento: null,
          },

          include: {
            plano: true,
          },
        });
    }

    // ==========================================
    // 5. CRIAR CHECKOUT ASAAS
    // ==========================================

    const checkout =
      await this.asaasService.criarCheckoutAssinatura(
        {
          assinaturaId:
            assinatura.id_assinatura,

          customerId:
            customer.asaas_customer_id,

          nomePlano:
            plano.nome,

          beneficios:
            plano.beneficios,

          valor:
            Number(plano.valor),

          periodoCobranca:
            plano.periodo_cobranca,
        },
      );

    // ==========================================
    // 6. SALVAR CHECKOUT NO PRISMA
    // ==========================================

    const atualizada =
      await this.prisma.assinatura.update({
        where: {
          id_assinatura:
            assinatura.id_assinatura,
        },

        data: {
          asaas_checkout_id:
            checkout.id,
        },

        include: {
          plano: true,
        },
      });

    // ==========================================
    // 7. RETORNAR URL
    // ==========================================

    return {
      assinatura:
        this.serializar(atualizada),

      checkout_id:
        checkout.id,

      checkout_url:
        checkout.url,

      checkout_reutilizado:
        false,
    };
  }

  // ============================================
  // HU38 - ASSINATURA ATUAL
  // ============================================

  async buscarAtual(
    usuarioId: string,
  ) {
    const atual =
      await this.buscarEmAberto(usuarioId);

    if (!atual) {
      throw new NotFoundException(
        'Você não possui assinatura em aberto',
      );
    }

    return this.serializar(atual);
  }

  // ============================================
  // HISTÓRICO DE ASSINATURAS
  // ============================================
  //
  // Retorna:
  //
  // - PENDENTE
  // - ATIVA
  // - SUSPENSA
  // - CANCELADA
  //
  async listar(
    usuarioId: string,
  ) {
    const assinaturas =
      await this.prisma.assinatura.findMany({
        where: {
          id_usuario:
            usuarioId,
        },

        include: {
          plano: true,
        },

        orderBy: {
          data_cadastro:
            'desc',
        },
      });

    return assinaturas.map(
      (assinatura) =>
        this.serializar(
          assinatura,
        ),
    );
  }

  // ============================================
  // HU39 - CANCELAR ASSINATURA
  // ============================================
  //
  // Neste momento:
  //
  // - altera a situação local;
  // - preserva o histórico;
  // - não exclui o registro.
  //
  // IMPORTANTE:
  //
  // Para assinatura ASAAS ATIVA, depois
  // adicionaremos aqui também o cancelamento
  // da assinatura recorrente no gateway.
  //
  async cancelarAtual(
    usuarioId: string,
  ) {
    const atual =
      await this.buscarEmAberto(usuarioId);

    if (!atual) {
      throw new NotFoundException(
        'Você não possui assinatura para cancelar',
      );
    }

    const cancelada =
      await this.prisma.assinatura.update({
        where: {
          id_assinatura:
            atual.id_assinatura,
        },

        data: {
          situacao:
            SituacaoAssinatura.CANCELADA,

          data_cancelamento:
            new Date(),
        },

        include: {
          plano: true,
        },
      });

    return this.serializar(
      cancelada,
    );
  }
}