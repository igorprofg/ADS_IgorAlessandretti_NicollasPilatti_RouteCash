import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import {
  AsaasCheckout,
  AsaasCustomer,
  AsaasListResponse,
  AsaasSubscriptionCycle,
} from './asaas.types';

type UsuarioParaAsaas = {
  id_usuario: string;
  nome: string;
  email: string;
  cpf_cnpj: string | null;
  celular: string | null;
  cep: string | null;
  logradouro: string | null;
  numero_endereco: string | null;
  complemento: string | null;
  bairro: string | null;
  asaas_customer_id: string | null;
};

type AsaasCheckoutComLink = AsaasCheckout & {
  link?: string;
  status?: string;
};

@Injectable()
export class AsaasService {
  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly userAgent: string;

  private readonly checkoutSuccessUrl: string;
  private readonly checkoutCancelUrl: string;
  private readonly checkoutExpiredUrl: string;

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    this.baseUrl = (
      this.configService.get<string>('ASAAS_BASE_URL') ??
      'https://api-sandbox.asaas.com/v3'
    ).replace(/\/$/, '');

    this.apiKey =
      this.configService.get<string>('ASAAS_API_KEY')?.trim() ?? '';

    this.userAgent =
      this.configService.get<string>('ASAAS_USER_AGENT')?.trim() ??
      'RouteCash/1.0';

    this.checkoutSuccessUrl =
      this.configService.get<string>('ASAAS_CHECKOUT_SUCCESS_URL') ??
      'https://example.com/routecash/sucesso';

    this.checkoutCancelUrl =
      this.configService.get<string>('ASAAS_CHECKOUT_CANCEL_URL') ??
      'https://example.com/routecash/cancelado';

    this.checkoutExpiredUrl =
      this.configService.get<string>('ASAAS_CHECKOUT_EXPIRED_URL') ??
      'https://example.com/routecash/expirado';
  }

  // ============================================
  // HEADERS ASAAS
  // ============================================

  private getHeaders(): Record<string, string> {
    if (!this.apiKey) {
      throw new InternalServerErrorException(
        'ASAAS_API_KEY não está configurada no .env.',
      );
    }

    return {
      accept: 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': this.userAgent,
      access_token: this.apiKey,
    };
  }

  // ============================================
  // REQUISIÇÃO GENÉRICA
  // ============================================

  private async request<T>(
    caminho: string,
    options: RequestInit = {},
  ): Promise<T> {
    try {
      const response = await fetch(`${this.baseUrl}${caminho}`, {
        ...options,
        headers: {
          ...this.getHeaders(),
          ...(options.headers ?? {}),
        },
      });

      const texto = await response.text();

      let body: unknown = null;

      if (texto) {
        try {
          body = JSON.parse(texto);
        } catch {
          body = texto;
        }
      }

      if (response.status === 401) {
        throw new UnauthorizedException(
          'API Key do Asaas inválida ou incompatível com o ambiente.',
        );
      }

      if (!response.ok) {
        throw new BadRequestException({
          mensagem: 'Erro retornado pelo Asaas.',
          status: response.status,
          resposta: body,
        });
      }

      return body as T;
    } catch (error) {
      if (
        error instanceof UnauthorizedException ||
        error instanceof BadRequestException ||
        error instanceof InternalServerErrorException
      ) {
        throw error;
      }

      throw new InternalServerErrorException(
        `Não foi possível comunicar com o Asaas: ${
          error instanceof Error ? error.message : 'Erro desconhecido'
        }`,
      );
    }
  }

  // ============================================
  // TESTE DE CONEXÃO
  // ============================================

  async testarConexao() {
    const resposta =
      await this.request<AsaasListResponse<AsaasCustomer>>(
        '/customers?limit=1',
        {
          method: 'GET',
        },
      );

    return {
      sucesso: true,
      ambiente: this.ehSandbox() ? 'SANDBOX' : 'PRODUÇÃO',
      mensagem: 'Conexão com o Asaas realizada com sucesso.',
      resposta,
    };
  }

  // ============================================
  // UTILITÁRIOS
  // ============================================

  private somenteNumeros(
    valor: string | null | undefined,
  ): string {
    if (!valor) {
      return '';
    }

    return valor.replace(/\D/g, '');
  }

  private ehSandbox(): boolean {
    return this.baseUrl.includes('api-sandbox.asaas.com');
  }

  private formatarDataHoraAsaas(data: Date): string {
    const pad = (numero: number) =>
      numero.toString().padStart(2, '0');

    return (
      `${data.getFullYear()}-` +
      `${pad(data.getMonth() + 1)}-` +
      `${pad(data.getDate())} ` +
      `${pad(data.getHours())}:` +
      `${pad(data.getMinutes())}:` +
      `${pad(data.getSeconds())}`
    );
  }

  private montarUrlCheckout(
    checkoutId: string,
    linkRetornado?: string,
  ): string {
    /*
     * Versões recentes da resposta do Checkout
     * podem retornar o próprio link público.
     *
     * Quando vier, damos preferência absoluta a ele.
     */
    if (linkRetornado?.trim()) {
      return linkRetornado.trim();
    }

    /*
     * Fallback para Sandbox.
     *
     * O Checkout 2.0 utiliza o domínio de Sandbox
     * para sessões criadas nesse ambiente.
     */
    if (this.ehSandbox()) {
      return `https://sandbox.asaas.com/checkoutSession/show/${checkoutId}`;
    }

    /*
     * Fallback de produção conforme documentação
     * pública do Checkout Asaas.
     */
    return `https://asaas.com/checkoutSession/show?id=${checkoutId}`;
  }

  // ============================================
  // CONVERTER PERÍODO ROUTE CASH -> ASAAS
  // ============================================

  private converterPeriodoParaCycle(
    periodo: string,
  ): AsaasSubscriptionCycle {
    const normalizado = periodo
      .trim()
      .toUpperCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '');

    switch (normalizado) {
      case 'SEMANAL':
      case 'WEEKLY':
        return 'WEEKLY';

      case 'QUINZENAL':
      case 'BIWEEKLY':
        return 'BIWEEKLY';

      case 'MENSAL':
      case 'MONTHLY':
        return 'MONTHLY';

      case 'BIMESTRAL':
      case 'BIMONTHLY':
        return 'BIMONTHLY';

      case 'TRIMESTRAL':
      case 'QUARTERLY':
        return 'QUARTERLY';

      case 'SEMESTRAL':
      case 'SEMIANNUALLY':
        return 'SEMIANNUALLY';

      case 'ANUAL':
      case 'YEARLY':
        return 'YEARLY';

      default:
        throw new BadRequestException(
          `Período de cobrança "${periodo}" não suportado pelo Asaas.`,
        );
    }
  }

  // ============================================
  // VALIDAR USUÁRIO PARA O ASAAS
  // ============================================

  private validarUsuarioParaAsaas(
    usuario: UsuarioParaAsaas,
  ) {
    if (!usuario.cpf_cnpj) {
      throw new BadRequestException(
        'O usuário precisa informar CPF/CNPJ antes de contratar um plano.',
      );
    }

    const cpfCnpj = this.somenteNumeros(
      usuario.cpf_cnpj,
    );

    if (
      cpfCnpj.length !== 11 &&
      cpfCnpj.length !== 14
    ) {
      throw new BadRequestException(
        'CPF/CNPJ do usuário possui formato inválido.',
      );
    }

    const celular = this.somenteNumeros(
      usuario.celular,
    );

    const cep = this.somenteNumeros(
      usuario.cep,
    );

    if (cep.length !== 8) {
      throw new BadRequestException(
        'O usuário precisa informar um CEP válido antes de contratar um plano.',
      );
    }

    if (!usuario.logradouro?.trim()) {
      throw new BadRequestException(
        'O usuário precisa informar o logradouro antes de contratar um plano.',
      );
    }

    if (!usuario.numero_endereco?.trim()) {
      throw new BadRequestException(
        'O usuário precisa informar o número do endereço antes de contratar um plano.',
      );
    }

    if (!usuario.bairro?.trim()) {
      throw new BadRequestException(
        'O usuário precisa informar o bairro antes de contratar um plano.',
      );
    }

    return {
      cpfCnpj,
      celular: celular || null,
      cep,
      logradouro: usuario.logradouro.trim(),
      numeroEndereco:
        usuario.numero_endereco.trim(),
      complemento:
        usuario.complemento?.trim() || null,
      bairro: usuario.bairro.trim(),
    };
  }

  // ============================================
  // BUSCAR CUSTOMER PELO USUÁRIO
  // ============================================

  private async buscarCustomerPorUsuario(
    usuarioId: string,
  ): Promise<AsaasCustomer | null> {
    const externalReference =
      encodeURIComponent(usuarioId);

    const resposta =
      await this.request<
        AsaasListResponse<AsaasCustomer>
      >(
        `/customers?externalReference=${externalReference}&limit=1`,
        {
          method: 'GET',
        },
      );

    return resposta.data.length > 0
      ? resposta.data[0]
      : null;
  }

  // ============================================
  // ATUALIZAR CUSTOMER EXISTENTE
  // ============================================

  private async atualizarCustomer(
    customerId: string,
    usuario: UsuarioParaAsaas,
  ): Promise<AsaasCustomer> {
    const dados =
      this.validarUsuarioParaAsaas(usuario);

    const payload: Record<string, unknown> = {
      name: usuario.nome,
      cpfCnpj: dados.cpfCnpj,
      email: usuario.email,

      postalCode: dados.cep,
      address: dados.logradouro,
      addressNumber: dados.numeroEndereco,
      province: dados.bairro,

      externalReference: usuario.id_usuario,
    };

    if (dados.celular) {
      payload.mobilePhone = dados.celular;
    }

    if (dados.complemento) {
      payload.complement = dados.complemento;
    }

    return this.request<AsaasCustomer>(
      `/customers/${customerId}`,
      {
        method: 'PUT',
        body: JSON.stringify(payload),
      },
    );
  }

  // ============================================
  // CRIAR CUSTOMER
  // ============================================

  private async criarCustomer(
    usuario: UsuarioParaAsaas,
  ): Promise<AsaasCustomer> {
    const dados =
      this.validarUsuarioParaAsaas(usuario);

    const payload: Record<string, unknown> = {
      name: usuario.nome,
      cpfCnpj: dados.cpfCnpj,
      email: usuario.email,

      postalCode: dados.cep,
      address: dados.logradouro,
      addressNumber: dados.numeroEndereco,
      province: dados.bairro,

      externalReference: usuario.id_usuario,
    };

    if (dados.celular) {
      payload.mobilePhone = dados.celular;
    }

    if (dados.complemento) {
      payload.complement = dados.complemento;
    }

    return this.request<AsaasCustomer>(
      '/customers',
      {
        method: 'POST',
        body: JSON.stringify(payload),
      },
    );
  }

  // ============================================
  // OBTER OU CRIAR CUSTOMER
  // ============================================

  async obterOuCriarCliente(
    usuarioId: string,
  ) {
    const usuario =
      await this.prisma.usuario.findUnique({
        where: {
          id_usuario: usuarioId,
        },
      });

    if (!usuario) {
      throw new NotFoundException(
        'Usuário não encontrado.',
      );
    }

    /*
     * Valida antes de qualquer comunicação
     * com o Asaas.
     */
    this.validarUsuarioParaAsaas(usuario);

    // ==========================================
    // CUSTOMER JÁ VINCULADO LOCALMENTE
    // ==========================================

    if (usuario.asaas_customer_id) {
      const customerAtualizado =
        await this.atualizarCustomer(
          usuario.asaas_customer_id,
          usuario,
        );

      return {
        customerId: customerAtualizado.id,
        asaas_customer_id:
          customerAtualizado.id,

        criado: false,
        recuperado: false,
        reutilizado: true,

        mensagem:
          'Customer existente atualizado e reutilizado no Asaas.',
      };
    }

    // ==========================================
    // VERIFICAR SE JÁ EXISTE NO ASAAS
    // ==========================================

    const existente =
      await this.buscarCustomerPorUsuario(
        usuarioId,
      );

    if (existente) {
      /*
       * Sincroniza os dados atuais do usuário
       * antes de reutilizar o Customer.
       */
      const customerAtualizado =
        await this.atualizarCustomer(
          existente.id,
          usuario,
        );

      await this.prisma.usuario.update({
        where: {
          id_usuario: usuarioId,
        },
        data: {
          asaas_customer_id:
            customerAtualizado.id,
        },
      });

      return {
        customerId: customerAtualizado.id,
        asaas_customer_id:
          customerAtualizado.id,

        criado: false,
        recuperado: true,
        reutilizado: false,

        mensagem:
          'Customer já existia no Asaas e foi vinculado novamente ao usuário.',
      };
    }

    // ==========================================
    // CRIAR NOVO CUSTOMER
    // ==========================================

    const customer =
      await this.criarCustomer(usuario);

    if (!customer.id) {
      throw new InternalServerErrorException(
        'O Asaas não retornou o ID do Customer criado.',
      );
    }

    await this.prisma.usuario.update({
      where: {
        id_usuario: usuarioId,
      },
      data: {
        asaas_customer_id: customer.id,
      },
    });

    return {
      customerId: customer.id,
      asaas_customer_id: customer.id,

      criado: true,
      recuperado: false,
      reutilizado: false,

      mensagem:
        'Customer criado no Asaas e vinculado ao usuário com sucesso.',

      customer: {
        id: customer.id,
        nome: customer.name,
        cpf_cnpj:
          customer.cpfCnpj ?? null,
        email:
          customer.email ?? null,
      },
    };
  }

  // ============================================
  // CRIAR CHECKOUT DE ASSINATURA
  // ============================================

  async criarCheckoutAssinatura(dados: {
    assinaturaId: string;
    customerId: string;
    nomePlano: string;
    beneficios?: string | null;
    valor: number;
    periodoCobranca: string;
  }) {
    if (!dados.assinaturaId) {
      throw new BadRequestException(
        'ID da assinatura é obrigatório.',
      );
    }

    if (!dados.customerId) {
      throw new BadRequestException(
        'Customer do Asaas é obrigatório.',
      );
    }

    if (!dados.nomePlano?.trim()) {
      throw new BadRequestException(
        'Nome do plano é obrigatório.',
      );
    }

    if (
      !Number.isFinite(dados.valor) ||
      dados.valor <= 0
    ) {
      throw new BadRequestException(
        'O valor do plano deve ser maior que zero.',
      );
    }

    const cycle =
      this.converterPeriodoParaCycle(
        dados.periodoCobranca,
      );

    /*
     * Deixamos a primeira cobrança alguns minutos
     * à frente para evitar problemas de horário
     * entre criação e processamento do Checkout.
     */
    const primeiraCobranca = new Date(
      Date.now() + 5 * 60 * 1000,
    );

    /*
     * O Checkout limita o tamanho de alguns campos.
     */
    const nomeItem =
      dados.nomePlano.trim().slice(0, 30);

    const descricaoItem = (
      dados.beneficios?.trim() ||
      `Assinatura ${dados.nomePlano} - Route Cash`
    ).slice(0, 150);

    const payload = {
      billingTypes: ['CREDIT_CARD'],
      chargeTypes: ['RECURRENT'],

      minutesToExpire: 60,

      /*
       * Relaciona o Checkout à assinatura
       * existente no banco do Route Cash.
       */
      externalReference:
        dados.assinaturaId,

      /*
       * Customer previamente criado/atualizado.
       */
      customer: dados.customerId,

      callback: {
        successUrl:
          this.checkoutSuccessUrl,
        cancelUrl:
          this.checkoutCancelUrl,
        expiredUrl:
          this.checkoutExpiredUrl,
      },

      items: [
        {
          name: nomeItem,
          description: descricaoItem,
          quantity: 1,
          value: dados.valor,
        },
      ],

      subscription: {
        cycle,
        nextDueDate:
          this.formatarDataHoraAsaas(
            primeiraCobranca,
          ),
      },
    };

    const checkout =
      await this.request<AsaasCheckoutComLink>(
        '/checkouts',
        {
          method: 'POST',
          body: JSON.stringify(payload),
        },
      );

    if (!checkout.id) {
      throw new InternalServerErrorException(
        'O Asaas não retornou o ID do Checkout.',
      );
    }

    /*
     * Log útil durante a fase de desenvolvimento.
     *
     * NÃO imprime API Key ou dados sensíveis.
     */
    console.log(
      '[ASAAS] Checkout criado:',
      {
        id: checkout.id,
        status: checkout.status ?? null,
        link: checkout.link ?? null,
        ambiente: this.ehSandbox()
          ? 'SANDBOX'
          : 'PRODUÇÃO',
      },
    );

    const checkoutUrl =
      this.montarUrlCheckout(
        checkout.id,
        checkout.link,
      );

    return {
      id: checkout.id,
      url: checkoutUrl,
    };
  }
}