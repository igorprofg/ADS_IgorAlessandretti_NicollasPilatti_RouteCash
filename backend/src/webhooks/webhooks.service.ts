import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
  InternalServerErrorException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { timingSafeEqual } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';

type AsaasWebhookPayload = {
  id: string;
  event: string;
  dateCreated?: string;
  [chave: string]: unknown;
};

@Injectable()
export class WebhooksService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(WebhooksService.name);
  private pollingTimer: ReturnType<typeof setInterval> | null = null;
  private executandoLote = false;

  // Polling em banco: sobrevive a reinicializações, sem depender da memória.
  onModuleInit(): void {
    this.pollingTimer = setInterval(() => { void this.processarLote(); }, 5000);
    this.pollingTimer.unref?.();
    // O primeiro processamento acontece mesmo sem novo webhook recebido.
    setImmediate(() => { void this.processarLote(); });
  }

  onModuleDestroy(): void {
    if (this.pollingTimer) clearInterval(this.pollingTimer);
    this.pollingTimer = null;
  }
  private readonly webhookToken: string;

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    this.webhookToken =
      this.configService
        .get<string>('ASAAS_WEBHOOK_TOKEN')
        ?.trim() ?? '';
  }

  // ==========================================
  // VALIDAÇÃO DO TOKEN
  // ==========================================

  private validarToken(
    tokenRecebido: string | undefined,
  ): void {
    if (!this.webhookToken) {
      throw new InternalServerErrorException(
        'ASAAS_WEBHOOK_TOKEN não está configurado no .env.',
      );
    }

    if (!tokenRecebido) {
      throw new UnauthorizedException(
        'Token do Webhook Asaas não informado.',
      );
    }

    const configurado = Buffer.from(
      this.webhookToken,
      'utf8',
    );

    const recebido = Buffer.from(
      tokenRecebido,
      'utf8',
    );

    const tokenValido =
      configurado.length === recebido.length &&
      timingSafeEqual(configurado, recebido);

    if (!tokenValido) {
      throw new UnauthorizedException(
        'Token do Webhook Asaas inválido.',
      );
    }
  }

  // ==========================================
  // VALIDAÇÃO DO PAYLOAD
  // ==========================================

  private validarPayload(
    payload: unknown,
  ): AsaasWebhookPayload {
    if (
      !payload ||
      typeof payload !== 'object' ||
      Array.isArray(payload)
    ) {
      throw new BadRequestException(
        'Payload do Webhook Asaas inválido.',
      );
    }

    const dados = payload as Record<string, unknown>;

    if (
      typeof dados.id !== 'string' ||
      !dados.id.trim()
    ) {
      throw new BadRequestException(
        'O Webhook Asaas não informou um id de evento válido.',
      );
    }

    if (
      typeof dados.event !== 'string' ||
      !dados.event.trim()
    ) {
      throw new BadRequestException(
        'O Webhook Asaas não informou um tipo de evento válido.',
      );
    }

    const id = dados.id.trim();
    const event = dados.event.trim();

    if (id.length > 150) {
      throw new BadRequestException(
        'O id do evento recebido excede o limite suportado.',
      );
    }

    if (event.length > 100) {
      throw new BadRequestException(
        'O tipo do evento recebido excede o limite suportado.',
      );
    }

    return {
      ...dados,
      id,
      event,
      dateCreated:
        typeof dados.dateCreated === 'string'
          ? dados.dateCreated
          : undefined,
    };
  }

  // ==========================================
  // DATA ATUAL - HORÁRIO DE BRASÍLIA
  // ==========================================

  private obterDataAtual(): Date {
    const partes = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'America/Sao_Paulo',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(new Date());

    const ano = Number(
      partes.find((p) => p.type === 'year')?.value,
    );

    const mes = Number(
      partes.find((p) => p.type === 'month')?.value,
    );

    const dia = Number(
      partes.find((p) => p.type === 'day')?.value,
    );

    return new Date(Date.UTC(ano, mes - 1, dia));
  }

  // ==========================================
  // CÁLCULO DO VENCIMENTO
  // ==========================================

  private calcularDataVencimento(
    dataInicio: Date,
    periodoCobranca: string,
  ): Date {
    const periodo =
      periodoCobranca.trim().toUpperCase();

    let meses: number;

    switch (periodo) {
      case 'MENSAL':
        meses = 1;
        break;

      case 'TRIMESTRAL':
        meses = 3;
        break;

      case 'SEMESTRAL':
        meses = 6;
        break;

      case 'ANUAL':
        meses = 12;
        break;

      default:
        throw new InternalServerErrorException(
          `Período de cobrança não suportado: ${periodoCobranca}`,
        );
    }

    const ano = dataInicio.getUTCFullYear();
    const mes = dataInicio.getUTCMonth();
    const dia = dataInicio.getUTCDate();

    // Identifica o último dia do mês de destino.
    // Evita que 31/01 + 1 mês resulte em março.
    const ultimoDiaMes = new Date(
      Date.UTC(ano, mes + meses + 1, 0),
    ).getUTCDate();

    return new Date(
      Date.UTC(
        ano,
        mes + meses,
        Math.min(dia, ultimoDiaMes),
      ),
    );
  }

  // ==========================================
  // CHECKOUT_PAID
  // ==========================================

  private async processarCheckoutPaid(
    tx: Prisma.TransactionClient,
    payload: AsaasWebhookPayload,
  ) {
    const checkout = payload.checkout;

    if (
      !checkout ||
      typeof checkout !== 'object' ||
      Array.isArray(checkout)
    ) {
      throw new BadRequestException(
        'O evento CHECKOUT_PAID não informou o checkout.',
      );
    }

    const dadosCheckout =
      checkout as Record<string, unknown>;

    if (
      typeof dadosCheckout.id !== 'string' ||
      !dadosCheckout.id.trim() ||
      dadosCheckout.id.trim().length > 100
    ) {
      throw new BadRequestException(
        'O evento CHECKOUT_PAID não informou um checkout.id válido.',
      );
    }

    const checkoutId = dadosCheckout.id.trim();

    // Localiza a assinatura vinculada ao checkout.
    const assinatura = await tx.assinatura.findUnique({
      where: {
        asaas_checkout_id: checkoutId,
      },
      include: {
        plano: true,
      },
    });

    if (!assinatura || assinatura.origem !== 'ASAAS') {
      throw new NotFoundException(
        `Assinatura Asaas não encontrada para o checkout ${checkoutId}.`,
      );
    }

    // Não altera assinaturas que já foram ativadas,
    // suspensas ou canceladas.
    if (assinatura.situacao !== 'PENDENTE') {
      return {
        assinatura_ativada: false,
        id_assinatura: assinatura.id_assinatura,
        situacao: assinatura.situacao,
        mensagem:
          'Assinatura não está pendente. Nenhuma alteração realizada.',
      };
    }

    const dataInicio = this.obterDataAtual();

    const dataVencimento =
      this.calcularDataVencimento(
        dataInicio,
        assinatura.plano.periodo_cobranca,
      );

    // Atualização condicional para impedir que dois
    // eventos simultâneos ativem a mesma assinatura.
    const resultado = await tx.assinatura.updateMany({
      where: {
        id_assinatura: assinatura.id_assinatura,
        situacao: 'PENDENTE',
        origem: 'ASAAS',
      },
      data: {
        situacao: 'ATIVA',
        data_inicio: dataInicio,
        data_vencimento: dataVencimento,
      },
    });

    if (resultado.count === 0) {
      const atual = await tx.assinatura.findUnique({
        where: {
          id_assinatura: assinatura.id_assinatura,
        },
      });

      return {
        assinatura_ativada: false,
        id_assinatura: assinatura.id_assinatura,
        situacao: atual?.situacao,
        mensagem:
          'A assinatura já foi alterada por outro processamento.',
      };
    }

    return {
      assinatura_ativada: true,
      id_assinatura: assinatura.id_assinatura,
      situacao: 'ATIVA',
      data_inicio: dataInicio,
      data_vencimento: dataVencimento,
      mensagem: 'Assinatura ativada com sucesso.',
    };
  }

  // ==========================================
// SUBSCRIPTION_CREATED
// ==========================================

private async processarSubscriptionCreated(
  tx: Prisma.TransactionClient,
  payload: AsaasWebhookPayload,
) {
  const subscription = payload.subscription;

  if (
    !subscription ||
    typeof subscription !== 'object' ||
    Array.isArray(subscription)
  ) {
    throw new BadRequestException(
      'O evento SUBSCRIPTION_CREATED não informou a assinatura.',
    );
  }

  const dadosSubscription =
    subscription as Record<string, unknown>;

  // Valida o ID da assinatura Asaas.
  if (
    typeof dadosSubscription.id !== 'string' ||
    !dadosSubscription.id.trim() ||
    dadosSubscription.id.trim().length > 100
  ) {
    throw new BadRequestException(
      'O evento não informou um subscription.id válido.',
    );
  }

  const subscriptionId =
    dadosSubscription.id.trim();

  // Valida o Customer.
  if (
    typeof dadosSubscription.customer !== 'string' ||
    !dadosSubscription.customer.trim()
  ) {
    throw new BadRequestException(
      'O evento não informou um Customer válido.',
    );
  }

  const customerId =
    dadosSubscription.customer.trim();

  // Obtém o ID do Checkout.
  const checkoutId =
    typeof dadosSubscription.checkoutSession === 'string'
      ? dadosSubscription.checkoutSession.trim()
      : null;

  // Obtém a referência externa, quando existir.
  const externalReference =
    typeof dadosSubscription.externalReference === 'string'
      ? dadosSubscription.externalReference.trim()
      : null;

  const uuidValido =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  if (
    externalReference &&
    !uuidValido.test(externalReference)
  ) {
    throw new BadRequestException(
      'Referência externa inválida.',
    );
  }

  // ==========================================
  // 1. BUSCAR PELO SUBSCRIPTION ID
  // ==========================================

  let assinatura = await tx.assinatura.findUnique({
    where: {
      asaas_subscription_id: subscriptionId,
    },
    include: {
      usuario: true,
    },
  });

  // ==========================================
  // 2. BUSCAR PELO CHECKOUT SESSION
  // ==========================================

  if (!assinatura && checkoutId) {
    assinatura = await tx.assinatura.findUnique({
      where: {
        asaas_checkout_id: checkoutId,
      },
      include: {
        usuario: true,
      },
    });
  }

  // ==========================================
  // 3. BUSCAR PELA REFERÊNCIA EXTERNA
  // ==========================================

  if (!assinatura && externalReference) {
    assinatura = await tx.assinatura.findUnique({
      where: {
        id_assinatura: externalReference,
      },
      include: {
        usuario: true,
      },
    });
  }

  // ==========================================
  // VALIDAR A ASSINATURA LOCALIZADA
  // ==========================================

  if (!assinatura || assinatura.origem !== 'ASAAS') {
    throw new NotFoundException(
      'Assinatura interna do Asaas não encontrada.',
    );
  }

  // Valida o proprietário da assinatura.
  if (
    assinatura.usuario.asaas_customer_id !== customerId
  ) {
    throw new ConflictException(
      'O Customer recebido não corresponde à assinatura.',
    );
  }

  // Valida a compatibilidade do Checkout.
  if (
    checkoutId &&
    assinatura.asaas_checkout_id !== checkoutId
  ) {
    throw new ConflictException(
      'O Checkout informado não corresponde à assinatura.',
    );
  }

  // Valida a referência externa, quando informada.
  if (
    externalReference &&
    assinatura.id_assinatura !== externalReference
  ) {
    throw new ConflictException(
      'Referência externa incompatível com a assinatura.',
    );
  }

  // Impede a substituição de um vínculo existente.
  if (
    assinatura.asaas_subscription_id &&
    assinatura.asaas_subscription_id !== subscriptionId
  ) {
    throw new ConflictException(
      'A assinatura já possui outro vínculo com o Asaas.',
    );
  }

  // Assinatura já vinculada corretamente.
  if (
    assinatura.asaas_subscription_id === subscriptionId
  ) {
    return {
      assinatura_vinculada: false,
      id_assinatura: assinatura.id_assinatura,
      asaas_subscription_id: subscriptionId,
      mensagem:
        'Assinatura Asaas já vinculada anteriormente.',
    };
  }

  // ==========================================
  // VINCULAR ASSINATURA
  // ==========================================

  const resultado = await tx.assinatura.updateMany({
    where: {
      id_assinatura: assinatura.id_assinatura,
      asaas_subscription_id: null,
      origem: 'ASAAS',
    },
    data: {
      asaas_subscription_id: subscriptionId,
    },
  });

  if (resultado.count === 0) {
    const atual = await tx.assinatura.findUnique({
      where: {
        id_assinatura: assinatura.id_assinatura,
      },
    });

    if (
      atual?.asaas_subscription_id === subscriptionId
    ) {
      return {
        assinatura_vinculada: false,
        id_assinatura: assinatura.id_assinatura,
        asaas_subscription_id: subscriptionId,
        mensagem:
          'Assinatura já vinculada por outro processamento.',
      };
    }

    throw new ConflictException(
      'Não foi possível vincular a assinatura Asaas.',
    );
  }

  return {
    assinatura_vinculada: true,
    id_assinatura: assinatura.id_assinatura,
    asaas_subscription_id: subscriptionId,
    asaas_checkout_id: assinatura.asaas_checkout_id,
    situacao: assinatura.situacao,
    mensagem:
      'Assinatura Asaas vinculada com sucesso.',
  };
}



// ==========================================
// PAYMENT_CREATED
// ==========================================

private async processarPaymentCreated(
  tx: Prisma.TransactionClient,
  payload: AsaasWebhookPayload,
) {
  const payment = payload.payment;

  // Valida o objeto da cobrança.
  if (
    !payment ||
    typeof payment !== 'object' ||
    Array.isArray(payment)
  ) {
    throw new BadRequestException(
      'O evento PAYMENT_CREATED não informou a cobrança.',
    );
  }

  const dadosPayment =
    payment as Record<string, unknown>;

  // Valida o ID da cobrança no Asaas.
  if (
    typeof dadosPayment.id !== 'string' ||
    !dadosPayment.id.trim() ||
    dadosPayment.id.trim().length > 100
  ) {
    throw new BadRequestException(
      'O evento não informou um payment.id válido.',
    );
  }

  const paymentId = dadosPayment.id.trim();

  // Cobranças que não pertencem a uma assinatura
  // não fazem parte do fluxo recorrente do Route Cash.
  if (
    dadosPayment.subscription === null ||
    dadosPayment.subscription === undefined
  ) {
    return {
      pagamento_criado: false,
      mensagem:
        'Cobrança sem assinatura recorrente ignorada.',
    };
  }

  if (
    typeof dadosPayment.subscription !== 'string' ||
    !dadosPayment.subscription.trim()
  ) {
    throw new BadRequestException(
      'O evento não informou uma assinatura válida.',
    );
  }

  const subscriptionId =
    dadosPayment.subscription.trim();

  // Valida o Customer da cobrança.
  if (
    typeof dadosPayment.customer !== 'string' ||
    !dadosPayment.customer.trim()
  ) {
    throw new BadRequestException(
      'O evento não informou um Customer válido.',
    );
  }

  const customerId =
    dadosPayment.customer.trim();

  // Valida o valor da cobrança.
  if (
    typeof dadosPayment.value !== 'number' ||
    !Number.isFinite(dadosPayment.value) ||
    dadosPayment.value <= 0
  ) {
    throw new BadRequestException(
      'O evento não informou um valor válido.',
    );
  }

  const valor = new Prisma.Decimal(
    dadosPayment.value,
  );

  if (
    valor.decimalPlaces() > 2 ||
    valor.greaterThan('9999999999.99')
  ) {
    throw new BadRequestException(
      'O valor excede a precisão suportada.',
    );
  }

  // Valida a data de vencimento.
  if (
    typeof dadosPayment.dueDate !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}$/.test(
      dadosPayment.dueDate,
    )
  ) {
    throw new BadRequestException(
      'O evento não informou um vencimento válido.',
    );
  }

  const dataVencimento = new Date(
    `${dadosPayment.dueDate}T00:00:00.000Z`,
  );

  if (
    Number.isNaN(dataVencimento.getTime()) ||
    dataVencimento.toISOString().slice(0, 10) !==
      dadosPayment.dueDate
  ) {
    throw new BadRequestException(
      'Data de vencimento inválida.',
    );
  }

  // O checkout permite vincular a assinatura mesmo quando
  // PAYMENT_CREATED chega antes de SUBSCRIPTION_CREATED.
  const checkoutId =
    typeof dadosPayment.checkoutSession === 'string'
      ? dadosPayment.checkoutSession.trim() || null
      : null;

  if (checkoutId && checkoutId.length > 100) {
    throw new BadRequestException('Checkout inválido.');
  }

  let assinatura = await tx.assinatura.findUnique({
    where: { asaas_subscription_id: subscriptionId },
    include: { usuario: true },
  });

  if (!assinatura && checkoutId) {
    assinatura = await tx.assinatura.findUnique({
      where: { asaas_checkout_id: checkoutId },
      include: { usuario: true },
    });
  }

  if (!assinatura || assinatura.origem !== 'ASAAS') {
    throw new NotFoundException(
      'Assinatura vinculada à cobrança não encontrada. Verifique o checkoutSession e o vínculo local antes de reenviar.',
    );
  }

  if (assinatura.usuario.asaas_customer_id !== customerId) {
    throw new ConflictException(
      'O Customer da cobrança não corresponde ao usuário da assinatura.',
    );
  }

  if (checkoutId && assinatura.asaas_checkout_id !== checkoutId) {
    throw new ConflictException(
      'O Checkout da cobrança não corresponde à assinatura.',
    );
  }

  if (assinatura.asaas_subscription_id &&
      assinatura.asaas_subscription_id !== subscriptionId) {
    throw new ConflictException(
      'A assinatura já possui outro vínculo com o Asaas.',
    );
  }

  if (!assinatura.asaas_subscription_id) {
    if (!checkoutId) {
      throw new BadRequestException('Checkout não informado para vinculação.');
    }
    await tx.assinatura.updateMany({
      where: {
        id_assinatura: assinatura.id_assinatura,
        origem: 'ASAAS',
        asaas_checkout_id: checkoutId,
        asaas_subscription_id: null,
      },
      data: { asaas_subscription_id: subscriptionId },
    });

    // Confere também se outro processamento vinculou a assinatura.
    const atual = await tx.assinatura.findUniqueOrThrow({
      where: { id_assinatura: assinatura.id_assinatura },
      include: { usuario: true },
    });

    if (atual.asaas_subscription_id !== subscriptionId ||
        atual.usuario.asaas_customer_id !== customerId ||
        atual.asaas_checkout_id !== checkoutId ||
        atual.origem !== 'ASAAS') {
      throw new ConflictException(
        'Não foi possível vincular a assinatura da cobrança.',
      );
    }

    assinatura = atual;
  }

  // Verifica se a cobrança já existe.
  const existente = await tx.pagamento.findUnique({
    where: {
      asaas_payment_id: paymentId,
    },
  });

  if (existente) {
    if (
      existente.id_assinatura !== assinatura.id_assinatura
    ) {
      throw new ConflictException(
        'A cobrança já está vinculada a outra assinatura.',
      );
    }

    return {
      pagamento_criado: false,
      id_pagamento: existente.id_pagamento,
      asaas_payment_id: paymentId,
      situacao: existente.situacao,
      mensagem:
        'Cobrança já registrada anteriormente.',
    };
  }

  // Registra a cobrança sem sobrescrever uma existente.
  const pagamento = await tx.pagamento.upsert({
    where: {
      asaas_payment_id: paymentId,
    },
    update: {},
    create: {
      id_assinatura: assinatura.id_assinatura,
      asaas_payment_id: paymentId,
      valor,
      data_vencimento: dataVencimento,
      data_pagamento: null,
      situacao: 'PENDENTE',
    },
  });

  if (
    pagamento.id_assinatura !== assinatura.id_assinatura
  ) {
    throw new ConflictException(
      'A cobrança possui um vínculo incompatível.',
    );
  }

  return {
    pagamento_criado: true,
    id_pagamento: pagamento.id_pagamento,
    id_assinatura: pagamento.id_assinatura,
    asaas_payment_id: pagamento.asaas_payment_id,
    valor: pagamento.valor,
    situacao: pagamento.situacao,
    data_vencimento: pagamento.data_vencimento,
    mensagem: 'Cobrança registrada com sucesso.',
  };
}

// ==========================================
// RENOVAÇÃO E REATIVAÇÃO DA ASSINATURA
// ==========================================

private async renovarAssinatura(
  tx: Prisma.TransactionClient,
  assinaturaId: string,
  dataVencimentoCobranca: Date,
) {
  const assinatura = await tx.assinatura.findUnique({
    where: {
      id_assinatura: assinaturaId,
    },
    include: {
      plano: true,
    },
  });

  if (!assinatura) {
    throw new NotFoundException(
      'Assinatura não encontrada para renovação.',
    );
  }

  // Somente assinaturas ASAAS ativas ou suspensas
  // podem ser renovadas.
  if (
    assinatura.origem !== 'ASAAS' ||
    !['ATIVA', 'SUSPENSA'].includes(
      assinatura.situacao,
    ) ||
    !assinatura.data_vencimento
  ) {
    return {
      assinatura_renovada: false,
      assinatura_reativada: false,
      mensagem:
        'Assinatura não está apta para renovação.',
    };
  }

  // Ignora cobranças de ciclos anteriores.
  if (
    dataVencimentoCobranca.getTime() <
    assinatura.data_vencimento.getTime()
  ) {
    return {
      assinatura_renovada: false,
      assinatura_reativada: false,
      data_vencimento: assinatura.data_vencimento,
      mensagem:
        'Ciclo da cobrança já contemplado pela assinatura.',
    };
  }

  const novoVencimento =
    this.calcularDataVencimento(
      dataVencimentoCobranca,
      assinatura.plano.periodo_cobranca,
    );

  const hoje = this.obterDataAtual();

  // Um pagamento antigo não deve reativar
  // uma assinatura cujo novo período já expirou.
  if (
    assinatura.situacao === 'SUSPENSA' &&
    novoVencimento.getTime() < hoje.getTime()
  ) {
    return {
      assinatura_renovada: false,
      assinatura_reativada: false,
      mensagem:
        'O pagamento não restabelece um período de acesso válido.',
    };
  }

  const reativacao =
    assinatura.situacao === 'SUSPENSA';

  // Atualização condicional para evitar
  // alterações concorrentes e duplicadas.
  const resultado = await tx.assinatura.updateMany({
    where: {
      id_assinatura: assinaturaId,
      origem: 'ASAAS',
      situacao: assinatura.situacao,
      data_vencimento: {
        lte: dataVencimentoCobranca,
        lt: novoVencimento,
      },
    },
    data: {
      data_vencimento: novoVencimento,
      situacao: 'ATIVA',
    },
  });

  if (resultado.count === 0) {
    return {
      assinatura_renovada: false,
      assinatura_reativada: false,
      mensagem:
        'Ciclo já renovado ou assinatura alterada.',
    };
  }

  return {
    assinatura_renovada: true,
    assinatura_reativada: reativacao,
    id_assinatura: assinaturaId,
    situacao: 'ATIVA',
    vencimento_anterior:
      assinatura.data_vencimento,
    novo_vencimento: novoVencimento,
    mensagem: reativacao
      ? 'Assinatura reativada e renovada com sucesso.'
      : 'Assinatura renovada com sucesso.',
  };
}

// ==========================================
// PAYMENT_CONFIRMED
// ==========================================

private async processarPaymentConfirmed(
  tx: Prisma.TransactionClient,
  payload: AsaasWebhookPayload,
) {
  const payment = payload.payment;

  // Valida o objeto da cobrança.
  if (
    !payment ||
    typeof payment !== 'object' ||
    Array.isArray(payment)
  ) {
    throw new BadRequestException(
      'O evento não informou a cobrança.',
    );
  }

  const dadosPayment =
    payment as Record<string, unknown>;

  // Valida o identificador da cobrança.
  if (
    typeof dadosPayment.id !== 'string' ||
    !dadosPayment.id.trim() ||
    dadosPayment.id.trim().length > 100
  ) {
    throw new BadRequestException(
      'O evento não informou um payment.id válido.',
    );
  }

  const paymentId = dadosPayment.id.trim();

  // Ignora cobranças sem assinatura recorrente.
  if (
    dadosPayment.subscription === null ||
    dadosPayment.subscription === undefined
  ) {
    return {
      pagamento_confirmado: false,
      mensagem:
        'Cobrança sem assinatura recorrente ignorada.',
    };
  }

  if (
    typeof dadosPayment.subscription !== 'string' ||
    !dadosPayment.subscription.trim()
  ) {
    throw new BadRequestException(
      'O evento não informou uma assinatura válida.',
    );
  }

  const subscriptionId =
    dadosPayment.subscription.trim();

  // Valida o Customer.
  if (
    typeof dadosPayment.customer !== 'string' ||
    !dadosPayment.customer.trim()
  ) {
    throw new BadRequestException(
      'O evento não informou um Customer válido.',
    );
  }

  const customerId = dadosPayment.customer.trim();

  // Localiza a cobrança e seus relacionamentos.
  const pagamento = await tx.pagamento.findUnique({
    where: {
      asaas_payment_id: paymentId,
    },
    include: {
      assinatura: {
        include: {
          usuario: true,
        },
      },
    },
  });

  if (!pagamento) {
    throw new NotFoundException(
      'Pagamento Asaas não encontrado.',
    );
  }

  // Valida o vínculo com a assinatura.
  if (
    pagamento.assinatura.origem !== 'ASAAS' ||
    pagamento.assinatura.asaas_subscription_id !==
      subscriptionId
  ) {
    throw new ConflictException(
      'O pagamento não pertence à assinatura informada.',
    );
  }

  // Valida o proprietário da cobrança.
  if (
    pagamento.assinatura.usuario.asaas_customer_id !==
      customerId
  ) {
    throw new ConflictException(
      'O Customer informado não corresponde ao pagamento.',
    );
  }

  // Se já estiver pago, não altera novamente.
  if (pagamento.situacao === 'PAGO') {
    return {
      pagamento_confirmado: false,
      id_pagamento: pagamento.id_pagamento,
      asaas_payment_id: paymentId,
      situacao: pagamento.situacao,
      data_pagamento: pagamento.data_pagamento,
      mensagem:
        'Pagamento já confirmado anteriormente.',
    };
  }

  // Obtém a data efetiva do pagamento.
  // Prioriza paymentDate e utiliza confirmedDate
  // quando a primeira não estiver disponível.
  const dataInformada =
    dadosPayment.paymentDate ??
    dadosPayment.confirmedDate;

  if (
    typeof dataInformada !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}$/.test(dataInformada)
  ) {
    throw new BadRequestException(
      'O evento não informou uma data de pagamento válida.',
    );
  }

  const dataPagamento = new Date(
    `${dataInformada}T00:00:00.000Z`,
  );

  if (
    Number.isNaN(dataPagamento.getTime()) ||
    dataPagamento.toISOString().slice(0, 10) !==
      dataInformada
  ) {
    throw new BadRequestException(
      'Data de pagamento inválida.',
    );
  }

  // Atualiza somente pagamentos ainda não pagos.
  const resultado = await tx.pagamento.updateMany({
    where: {
      id_pagamento: pagamento.id_pagamento,
      situacao: {
        in: ['PENDENTE', 'VENCIDO'],
      },
    },
    data: {
      situacao: 'PAGO',
      data_pagamento: dataPagamento,
    },
  });

  if (resultado.count === 0) {
    const atual = await tx.pagamento.findUnique({
      where: {
        id_pagamento: pagamento.id_pagamento,
      },
    });

    return {
      pagamento_confirmado: false,
      id_pagamento: pagamento.id_pagamento,
      situacao: atual?.situacao,
      data_pagamento: atual?.data_pagamento,
      mensagem:
        'Pagamento já alterado por outro processamento.',
    };
  }

  // A confirmação e a renovação compartilham a mesma transação.
  // Cobrança confirmada não ativa assinatura local PENDENTE sem CHECKOUT_PAID.
  const renovacao = await this.renovarAssinatura(
    tx,
    pagamento.id_assinatura,
    pagamento.data_vencimento,
  );

  return {
    pagamento_confirmado: true,
    id_pagamento: pagamento.id_pagamento,
    id_assinatura: pagamento.id_assinatura,
    asaas_payment_id: paymentId,
    situacao: 'PAGO',
    data_pagamento: dataPagamento,
    renovacao,
    mensagem: 'Pagamento confirmado com sucesso.',
  };
}




// ==========================================
// PAYMENT_OVERDUE
// ==========================================

private async processarPaymentOverdue(
  tx: Prisma.TransactionClient,
  payload: AsaasWebhookPayload,
) {
  const payment = payload.payment;

  if (
    !payment ||
    typeof payment !== 'object' ||
    Array.isArray(payment)
  ) {
    throw new BadRequestException(
      'O evento não informou a cobrança.',
    );
  }

  const dadosPayment =
    payment as Record<string, unknown>;

  // Valida o identificador da cobrança.
  if (
    typeof dadosPayment.id !== 'string' ||
    !dadosPayment.id.trim() ||
    dadosPayment.id.trim().length > 100
  ) {
    throw new BadRequestException(
      'O evento não informou um payment.id válido.',
    );
  }

  const paymentId = dadosPayment.id.trim();

  // Ignora cobranças sem assinatura recorrente.
  if (
    dadosPayment.subscription === null ||
    dadosPayment.subscription === undefined
  ) {
    return {
      pagamento_vencido: false,
      mensagem:
        'Cobrança sem assinatura recorrente ignorada.',
    };
  }

  if (
    typeof dadosPayment.subscription !== 'string' ||
    !dadosPayment.subscription.trim()
  ) {
    throw new BadRequestException(
      'O evento não informou uma assinatura válida.',
    );
  }

  const subscriptionId =
    dadosPayment.subscription.trim();

  if (
    typeof dadosPayment.customer !== 'string' ||
    !dadosPayment.customer.trim()
  ) {
    throw new BadRequestException(
      'O evento não informou um Customer válido.',
    );
  }

  const customerId = dadosPayment.customer.trim();

  // Localiza o pagamento.
  const pagamento = await tx.pagamento.findUnique({
    where: {
      asaas_payment_id: paymentId,
    },
    include: {
      assinatura: {
        include: {
          usuario: true,
        },
      },
    },
  });

  if (!pagamento) {
    throw new NotFoundException(
      'Pagamento Asaas não encontrado.',
    );
  }

  // Valida o vínculo com a assinatura.
  if (
    pagamento.assinatura.origem !== 'ASAAS' ||
    pagamento.assinatura.asaas_subscription_id !==
      subscriptionId
  ) {
    throw new ConflictException(
      'O pagamento não pertence à assinatura informada.',
    );
  }

  // Valida o Customer.
  if (
    pagamento.assinatura.usuario.asaas_customer_id !==
      customerId
  ) {
    throw new ConflictException(
      'O Customer informado não corresponde ao pagamento.',
    );
  }

  // Eventos atrasados não podem alterar
  // pagamentos que já foram confirmados.
  if (pagamento.situacao === 'PAGO') {
    return {
      pagamento_vencido: false,
      assinatura_suspensa: false,
      situacao: 'PAGO',
      mensagem:
        'Pagamento já confirmado. Evento ignorado.',
    };
  }

  const hoje = this.obterDataAtual();

  if (
    pagamento.data_vencimento.getTime() >=
    hoje.getTime()
  ) {
    throw new BadRequestException(
      'A data de vencimento da cobrança ainda não passou.',
    );
  }

  // Atualiza somente pagamentos pendentes.
  const resultado = await tx.pagamento.updateMany({
    where: {
      id_pagamento: pagamento.id_pagamento,
      situacao: 'PENDENTE',
    },
    data: {
      situacao: 'VENCIDO',
    },
  });

  const pagamentoAtual =
    await tx.pagamento.findUniqueOrThrow({
      where: {
        id_pagamento: pagamento.id_pagamento,
      },
    });

  if (pagamentoAtual.situacao !== 'VENCIDO') {
    return {
      pagamento_vencido: false,
      assinatura_suspensa: false,
      situacao: pagamentoAtual.situacao,
      mensagem:
        'Pagamento alterado por outro processamento.',
    };
  }

  // Suspende somente assinaturas ativas
  // cujo período de acesso já terminou.
  const suspensao = await tx.assinatura.updateMany({
    where: {
      id_assinatura: pagamento.id_assinatura,
      origem: 'ASAAS',
      situacao: 'ATIVA',
      data_vencimento: {
        lt: hoje,
      },
    },
    data: {
      situacao: 'SUSPENSA',
    },
  });

  return {
    pagamento_vencido: resultado.count > 0,
    assinatura_suspensa: suspensao.count > 0,
    id_pagamento: pagamento.id_pagamento,
    id_assinatura: pagamento.id_assinatura,
    asaas_payment_id: paymentId,
    situacao: 'VENCIDO',
    mensagem:
      suspensao.count > 0
        ? 'Pagamento vencido e assinatura suspensa.'
        : 'Pagamento vencido registrado com sucesso.',
  };
}

// ==========================================
// SUBSCRIPTION_DELETED
// ==========================================

private async processarSubscriptionDeleted(
  tx: Prisma.TransactionClient,
  payload: AsaasWebhookPayload,
) {
  const subscription = payload.subscription;

  // Valida o objeto da assinatura.
  if (
    !subscription ||
    typeof subscription !== 'object' ||
    Array.isArray(subscription)
  ) {
    throw new BadRequestException(
      'O evento não informou a assinatura.',
    );
  }

  const dadosSubscription =
    subscription as Record<string, unknown>;

  // Valida o identificador da assinatura Asaas.
  if (
    typeof dadosSubscription.id !== 'string' ||
    !dadosSubscription.id.trim() ||
    dadosSubscription.id.trim().length > 100
  ) {
    throw new BadRequestException(
      'O evento não informou um subscription.id válido.',
    );
  }

  const subscriptionId =
    dadosSubscription.id.trim();

  // Valida o Customer.
  if (
    typeof dadosSubscription.customer !== 'string' ||
    !dadosSubscription.customer.trim()
  ) {
    throw new BadRequestException(
      'O evento não informou um Customer válido.',
    );
  }

  const customerId =
    dadosSubscription.customer.trim();

  // Localiza a assinatura interna.
  const assinatura = await tx.assinatura.findUnique({
    where: {
      asaas_subscription_id: subscriptionId,
    },
    include: {
      usuario: true,
    },
  });

  if (!assinatura || assinatura.origem !== 'ASAAS') {
    throw new NotFoundException(
      'Assinatura Asaas não encontrada.',
    );
  }

  // Confirma o proprietário da assinatura.
  if (
    assinatura.usuario.asaas_customer_id !== customerId
  ) {
    throw new ConflictException(
      'O Customer informado não corresponde à assinatura.',
    );
  }

  // Evita cancelar novamente uma assinatura
  // que já foi cancelada anteriormente.
  if (assinatura.situacao === 'CANCELADA') {
    return {
      assinatura_cancelada: false,
      id_assinatura: assinatura.id_assinatura,
      situacao: assinatura.situacao,
      data_cancelamento: assinatura.data_cancelamento,
      mensagem:
        'Assinatura já cancelada anteriormente.',
    };
  }

  const dataCancelamento = new Date();

  // Atualiza somente assinaturas ainda não canceladas.
  const resultado = await tx.assinatura.updateMany({
    where: {
      id_assinatura: assinatura.id_assinatura,
      origem: 'ASAAS',
      situacao: {
        in: ['ATIVA', 'SUSPENSA', 'PENDENTE'],
      },
    },
    data: {
      situacao: 'CANCELADA',
      data_cancelamento: dataCancelamento,
    },
  });

  if (resultado.count === 0) {
    return {
      assinatura_cancelada: false,
      id_assinatura: assinatura.id_assinatura,
      mensagem:
        'Assinatura já alterada por outro processamento.',
    };
  }

  return {
    assinatura_cancelada: true,
    id_assinatura: assinatura.id_assinatura,
    asaas_subscription_id: subscriptionId,
    situacao: 'CANCELADA',
    data_cancelamento: dataCancelamento,
    mensagem:
      'Assinatura cancelada com sucesso.',
  };
}

// ==========================================
// PAYMENT_DELETED
// ==========================================

private async processarPaymentDeleted(
  tx: Prisma.TransactionClient,
  payload: AsaasWebhookPayload,
) {
  const payment = payload.payment;

  // Valida o objeto da cobrança.
  if (
    !payment ||
    typeof payment !== 'object' ||
    Array.isArray(payment)
  ) {
    throw new BadRequestException(
      'O evento não informou a cobrança.',
    );
  }

  const dadosPayment =
    payment as Record<string, unknown>;

  // Valida o ID da cobrança.
  if (
    typeof dadosPayment.id !== 'string' ||
    !dadosPayment.id.trim() ||
    dadosPayment.id.trim().length > 100
  ) {
    throw new BadRequestException(
      'O evento não informou um payment.id válido.',
    );
  }

  const paymentId = dadosPayment.id.trim();

  // Ignora cobranças sem assinatura recorrente.
  if (
    dadosPayment.subscription === null ||
    dadosPayment.subscription === undefined
  ) {
    return {
      pagamento_cancelado: false,
      mensagem:
        'Cobrança sem assinatura recorrente ignorada.',
    };
  }

  if (
    typeof dadosPayment.subscription !== 'string' ||
    !dadosPayment.subscription.trim()
  ) {
    throw new BadRequestException(
      'O evento não informou uma assinatura válida.',
    );
  }

  const subscriptionId =
    dadosPayment.subscription.trim();

  // Valida o Customer.
  if (
    typeof dadosPayment.customer !== 'string' ||
    !dadosPayment.customer.trim()
  ) {
    throw new BadRequestException(
      'O evento não informou um Customer válido.',
    );
  }

  const customerId = dadosPayment.customer.trim();

  // Localiza o pagamento.
  const pagamento = await tx.pagamento.findUnique({
    where: {
      asaas_payment_id: paymentId,
    },
    include: {
      assinatura: {
        include: {
          usuario: true,
        },
      },
    },
  });

  if (!pagamento) {
    throw new NotFoundException(
      'Pagamento Asaas não encontrado.',
    );
  }

  // Valida o vínculo com a assinatura.
  if (
    pagamento.assinatura.origem !== 'ASAAS' ||
    pagamento.assinatura.asaas_subscription_id !==
      subscriptionId
  ) {
    throw new ConflictException(
      'O pagamento não pertence à assinatura informada.',
    );
  }

  // Valida o proprietário da cobrança.
  if (
    pagamento.assinatura.usuario.asaas_customer_id !==
      customerId
  ) {
    throw new ConflictException(
      'O Customer informado não corresponde ao pagamento.',
    );
  }

  // Preserva pagamentos já confirmados.
  if (pagamento.situacao === 'PAGO') {
    return {
      pagamento_cancelado: false,
      id_pagamento: pagamento.id_pagamento,
      situacao: 'PAGO',
      mensagem:
        'Pagamento já confirmado. Evento ignorado.',
    };
  }

  // Impede cancelamento repetido.
  if (pagamento.situacao === 'CANCELADO') {
    return {
      pagamento_cancelado: false,
      id_pagamento: pagamento.id_pagamento,
      situacao: 'CANCELADO',
      mensagem:
        'Pagamento já cancelado anteriormente.',
    };
  }

  // Cancela somente pagamentos pendentes ou vencidos.
  const resultado = await tx.pagamento.updateMany({
    where: {
      id_pagamento: pagamento.id_pagamento,
      situacao: {
        in: ['PENDENTE', 'VENCIDO'],
      },
    },
    data: {
      situacao: 'CANCELADO',
    },
  });

  if (resultado.count === 0) {
    const atual = await tx.pagamento.findUnique({
      where: {
        id_pagamento: pagamento.id_pagamento,
      },
    });

    return {
      pagamento_cancelado: false,
      id_pagamento: pagamento.id_pagamento,
      situacao: atual?.situacao,
      mensagem:
        'Pagamento já alterado por outro processamento.',
    };
  }

  return {
    pagamento_cancelado: true,
    id_pagamento: pagamento.id_pagamento,
    id_assinatura: pagamento.id_assinatura,
    asaas_payment_id: paymentId,
    situacao: 'CANCELADO',
    mensagem: 'Pagamento cancelado com sucesso.',
  };
}

  // ==========================================
  // DISPATCHER DOS EVENTOS ASAAS
  // ==========================================
  // Os eventos podem chegar fora de ordem. A criação e a confirmação
  // de uma mesma cobrança são processadas na mesma transação Prisma.
  // Não relacionar uma cobrança a uma assinatura por simples coincidência
  // de usuário/valor: a identificação usa IDs do Asaas e checkout.
  private async processarEvento(
    tx: Prisma.TransactionClient,
    payload: AsaasWebhookPayload,
  ) {
    switch (payload.event) {
      case 'CHECKOUT_PAID':
        return this.processarCheckoutPaid(tx, payload);

      case 'SUBSCRIPTION_CREATED':
        return this.processarSubscriptionCreated(tx, payload);

      case 'PAYMENT_CREATED': {
        // O Asaas pode criar uma cobrança que já chega CONFIRMED.
        const criacao = await this.processarPaymentCreated(tx, payload);
        const dados = payload.payment;
        if (
          dados &&
          typeof dados === 'object' &&
          !Array.isArray(dados) &&
          ['CONFIRMED', 'RECEIVED'].includes(
            String((dados as Record<string, unknown>).status ?? ''),
          )
        ) {
          const confirmacao = await this.processarPaymentConfirmed(tx, payload);
          return { ...criacao, confirmacao, mensagem: 'Cobrança registrada e confirmação processada.' };
        }
        return criacao;
      }

      case 'PAYMENT_CONFIRMED':
      case 'PAYMENT_RECEIVED': {
        const dados = payload.payment;
        if (!dados || typeof dados !== 'object' || Array.isArray(dados)) {
          throw new BadRequestException('O evento não informou a cobrança.');
        }
        const paymentId = (dados as Record<string, unknown>).id;
        if (typeof paymentId !== 'string' || !paymentId.trim()) {
          throw new BadRequestException('O evento não informou um payment.id válido.');
        }

        const existente = await tx.pagamento.findUnique({
          where: { asaas_payment_id: paymentId.trim() },
        });

        if (!existente) {
          // Corrige chegada fora de ordem: PAYMENT_CONFIRMED antes de
          // PAYMENT_CREATED. O método de criação valida checkout,
          // assinatura e customer antes de persistir o pagamento.
          // Se não houver vínculo local, ERRO: não ativar contas erradas.
          await this.processarPaymentCreated(tx, payload);
        }
        return this.processarPaymentConfirmed(tx, payload);
      }

      case 'PAYMENT_OVERDUE':
        return this.processarPaymentOverdue(tx, payload);

      case 'SUBSCRIPTION_DELETED':
        return this.processarSubscriptionDeleted(tx, payload);

      case 'PAYMENT_DELETED':
        return this.processarPaymentDeleted(tx, payload);

      default:
        // Evento desconhecido é identificado e registrado, sem falha 500.
        return { mensagem: 'Evento recebido sem regra de negócio implementada.' };
    }
  }

  // ==========================================
  // INBOX DURÁVEL DOS WEBHOOKS ASAAS
  // ==========================================
  // IMPORTANTE: o Asaas considera a entrega concluída após HTTP 200.
  // Esse retorno SÓ acontece depois do COMMIT do payload no PostgreSQL.
  // A regra financeira executa em transação independente, com reprocessamento.
  // Não usar 200 se a persistência falhar.

  /** Guarda apenas os campos necessários; dados de cartão/token NÃO são armazenados. */
  private payloadMinimo(payload: AsaasWebhookPayload): Prisma.InputJsonObject {
    const campos = (valor: unknown, permitidos: string[]): Prisma.InputJsonObject | undefined => {
      if (!valor || typeof valor !== 'object' || Array.isArray(valor)) return undefined;
      const origem = valor as Record<string, unknown>;
      const destino: Record<string, Prisma.InputJsonValue> = {};
      for (const chave of permitidos) {
        const item = origem[chave];
        if (typeof item === 'string' || typeof item === 'number' ||
            typeof item === 'boolean') {
          destino[chave] = item;
        }
      }
      return destino;
    };

    return {
      id: payload.id,
      event: payload.event,
      ...(payload.dateCreated ? { dateCreated: payload.dateCreated } : {}),
      ...(payload.checkout ? { checkout: campos(payload.checkout,
        ['id', 'status', 'customer', 'externalReference']) ?? {} } : {}),
      ...(payload.subscription ? { subscription: campos(payload.subscription,
        ['id', 'customer', 'checkoutSession', 'externalReference']) ?? {} } : {}),
      ...(payload.payment ? { payment: campos(payload.payment,
        ['id', 'subscription', 'customer', 'checkoutSession', 'externalReference',
         'status', 'value', 'dueDate', 'paymentDate', 'confirmedDate']) ?? {} } : {}),
    };
  }

  async receberEventoAsaas(
    tokenRecebido: string | undefined,
    payloadRecebido: unknown,
  ) {
    this.validarToken(tokenRecebido);
    const payload = this.validarPayload(payloadRecebido);
    const seguro = this.payloadMinimo(payload);

    // Não sobrescreve um evento existente; preserva idempotência e evidências.
    // P2002 é esperado quando o Asaas envia duas cópias ao mesmo tempo.
    let duplicado = false;
    try {
      await this.prisma.eventoWebhook.create({
        data: {
          id_evento: payload.id,
          provedor: 'ASAAS',
          tipo: payload.event,
          payload: seguro,
          situacao: 'PENDENTE',
        },
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        duplicado = true;
      } else {
        // Sem persistência não pode confirmar o recebimento ao Asaas.
        throw error;
      }
    }

    // O worker será acionado periodicamente; sem aguardar o processamento
    // financeiro no request HTTP. Isso evita bloquear a fila do Asaas.
    return {
      recebido: true,
      duplicado,
      id_evento: payload.id,
      evento: payload.event,
      mensagem: 'Webhook armazenado para processamento seguro.',
    };
  }

  private async processarLote(): Promise<void> {
    if (this.executandoLote) return;
    this.executandoLote = true;
    try {
      const agora = new Date();
      // Eventos cujo processo morreu antes do COMMIT podem ser retomados.
      const pendentes = await this.prisma.eventoWebhook.findMany({
        where: {
          OR: [
            { situacao: 'PENDENTE', proxima_tentativa_em: { lte: agora } },
            { situacao: 'PROCESSANDO', bloqueado_ate: { lt: agora } },
          ],
        },
        orderBy: { recebido_em: 'asc' },
        take: 20,
        select: { id_evento: true },
      });
      for (const item of pendentes) await this.processarArmazenado(item.id_evento);
    } catch (error) {
      this.logger.error('Falha ao consultar inbox de webhooks',
        error instanceof Error ? error.stack : String(error));
    } finally {
      this.executandoLote = false;
    }
  }

  private async processarArmazenado(idEvento: string): Promise<void> {
    const agora = new Date();
    const bloqueadoAte = new Date(agora.getTime() + 2 * 60 * 1000);
    // Claim atômico: múltiplos processos NestJS não pegam o mesmo evento.
    const claim = await this.prisma.eventoWebhook.updateMany({
      where: {
        id_evento: idEvento,
        OR: [
          { situacao: 'PENDENTE', proxima_tentativa_em: { lte: agora } },
          { situacao: 'PROCESSANDO', bloqueado_ate: { lt: agora } },
        ],
      },
      data: {
        situacao: 'PROCESSANDO',
        bloqueado_ate: bloqueadoAte,
        ultima_tentativa_em: agora,
        tentativas: { increment: 1 },
      },
    });
    if (claim.count === 0) return;

    const evento = await this.prisma.eventoWebhook.findUniqueOrThrow({
      where: { id_evento: idEvento },
    });

    try {
      // Processamento financeiro + marcação de sucesso no MESMO COMMIT.
      // Se o NestJS morrer antes do COMMIT, nada é confirmado parcialmente.
      await this.prisma.$transaction(async tx => {
        const payload = this.validarPayload(evento.payload);
        await this.processarEvento(tx, payload);
        await tx.eventoWebhook.update({
          where: { id_evento: idEvento },
          data: {
            situacao: 'PROCESSADO',
            processado_em: new Date(),
            bloqueado_ate: null,
            erro: null,
          },
        });
      }, { timeout: 20000 });
      this.logger.log(`[ASAAS] Processado: ${evento.tipo} / ${idEvento}`);
    } catch (error) {
      const mensagem = error instanceof Error ? error.message : String(error);
      const semVinculo = error instanceof NotFoundException ||
        error instanceof ConflictException || error instanceof BadRequestException;
      const limite = evento.tentativas >= 7; // inclui uma tentativa iniciada no claim
      const reconciliacao = semVinculo || limite;
      const minutos = Math.min(60, 2 ** Math.min(evento.tentativas, 5));
      try {
        await this.prisma.eventoWebhook.updateMany({
          where: { id_evento: idEvento, situacao: 'PROCESSANDO' },
          data: {
            situacao: reconciliacao ? 'RECONCILIACAO' : 'PENDENTE',
            bloqueado_ate: null,
            erro: mensagem.slice(0, 2000),
            proxima_tentativa_em: new Date(Date.now() + minutos * 60000),
          },
        });
      } catch (persistError) {
        this.logger.error(`Erro ao registrar falha do webhook ${idEvento}`,
          persistError instanceof Error ? persistError.stack : String(persistError));
        // A marca PROCESSANDO expira pelo lease e o evento volta a ser elegível.
      }
      this.logger.warn(`[ASAAS] ${reconciliacao ? 'RECONCILIACAO' : 'RETRY'}: ` +
        `${evento.tipo} / ${idEvento}: ${mensagem}`);
    }
  }
}
