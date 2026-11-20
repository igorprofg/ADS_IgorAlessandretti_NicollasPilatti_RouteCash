import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OrigemAssinatura, Prisma, SituacaoPagamento } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { hojeComoData } from '../common/periodo-cobranca';
import { ConsultarPagamentosDto } from './dto/consultar-pagamentos.dto';
import { RegistrarPagamentoDto } from './dto/registrar-pagamento.dto';
import { AtualizarSituacaoPagamentoDto } from './dto/atualizar-situacao-pagamento.dto';

export type PagamentoCompleto = Prisma.PagamentoGetPayload<{
  include: {
    assinatura: {
      include: {
        usuario: { select: { id_usuario: true; nome: true; email: true } };
        plano: { select: { nome: true } };
      };
    };
  };
}>;

const INCLUIR_COMPLETO = {
  assinatura: {
    include: {
      usuario: { select: { id_usuario: true, nome: true, email: true } },
      plano: { select: { nome: true } },
    },
  },
} as const;

const dia = (data: Date) => data.toISOString().slice(0, 10);

// Lê 'AAAA-MM-DD' como data (UTC) e recusa datas que não existem (ex.: 2026-02-30)
function lerData(texto: string, campo: string): Date {
  const data = new Date(`${texto}T00:00:00.000Z`);
  if (Number.isNaN(data.getTime()) || dia(data) !== texto) {
    throw new BadRequestException(`${campo} é uma data inválida`);
  }
  return data;
}

// RF18: o administrador registra e acompanha manualmente os pagamentos das assinaturas.
// Pagamentos criados pelo Webhook do Asaas (com asaas_payment_id) aparecem aqui, mas ficam
// protegidos contra alteração manual; e não se registra pagamento manual em assinatura de
// origem ASAAS, cujas cobranças são do gateway.
// Não existe exclusão nem edição de valor/vencimento: o histórico é preservado.
@Injectable()
export class PagamentosAdminService {
  constructor(private readonly prisma: PrismaService) {}

  private serializar(p: PagamentoCompleto) {
    return {
      id_pagamento: p.id_pagamento,
      id_assinatura: p.id_assinatura,
      valor: Number(p.valor),
      data_vencimento: dia(p.data_vencimento),
      data_pagamento: p.data_pagamento ? dia(p.data_pagamento) : null,
      situacao: p.situacao,
      // Calculado: a situação gravada não muda sozinha quando o vencimento passa
      em_atraso:
        p.situacao === SituacaoPagamento.PENDENTE &&
        p.data_vencimento.getTime() < hojeComoData().getTime(),
      // Calculada a partir do asaas_payment_id (sem coluna nova)
      origem: p.asaas_payment_id !== null ? ('ASAAS' as const) : ('MANUAL' as const),
      assinatura_situacao: p.assinatura.situacao,
      usuario: {
        id_usuario: p.assinatura.usuario.id_usuario,
        nome: p.assinatura.usuario.nome,
        email: p.assinatura.usuario.email,
      },
      plano_nome: p.assinatura.plano.nome,
    };
  }

  private async obter(id: string) {
    const pagamento = await this.prisma.pagamento.findUnique({
      where: { id_pagamento: id },
      include: INCLUIR_COMPLETO,
    });
    if (!pagamento) {
      throw new NotFoundException('Pagamento não encontrado');
    }
    return pagamento;
  }

  // Data do pagamento só existe quando a situação é PAGO (e não pode ser futura)
  private resolverDataPagamento(situacao: SituacaoPagamento, texto?: string) {
    if (situacao !== SituacaoPagamento.PAGO) {
      if (texto) {
        throw new BadRequestException(
          'data_pagamento só pode ser informada para pagamento pago',
        );
      }
      return null;
    }
    if (!texto) {
      return hojeComoData();
    }
    const data = lerData(texto, 'data_pagamento');
    if (data.getTime() > hojeComoData().getTime()) {
      throw new BadRequestException('A data do pagamento não pode ser futura');
    }
    return data;
  }

  // HU53: listar, pesquisar (usuário ou plano) e filtrar por situação
  async listar(filtro: ConsultarPagamentosDto) {
    const pagina = filtro.pagina ?? 1;
    const limite = filtro.limite ?? 20;
    const busca = filtro.busca?.trim();

    const where: Prisma.PagamentoWhereInput = {
      ...(filtro.situacao && { situacao: filtro.situacao }),
      ...(filtro.id_assinatura && { id_assinatura: filtro.id_assinatura }),
      ...(busca && {
        assinatura: {
          OR: [
            { usuario: { nome: { contains: busca, mode: 'insensitive' as const } } },
            { usuario: { email: { contains: busca, mode: 'insensitive' as const } } },
            { plano: { nome: { contains: busca, mode: 'insensitive' as const } } },
          ],
        },
      }),
    };

    const [pagamentos, total] = await Promise.all([
      this.prisma.pagamento.findMany({
        where,
        include: INCLUIR_COMPLETO,
        orderBy: [{ data_vencimento: 'desc' }, { data_cadastro: 'desc' }],
        skip: (pagina - 1) * limite,
        take: limite,
      }),
      this.prisma.pagamento.count({ where }),
    ]);

    return {
      itens: pagamentos.map((p) => this.serializar(p)),
      total,
      pagina,
      limite,
    };
  }

  async buscarUm(id: string) {
    return this.serializar(await this.obter(id));
  }

  // HU52: registrar. Não muda a situação da assinatura (isso é do RF17).
  async registrar(dto: RegistrarPagamentoDto) {
    const assinatura = await this.prisma.assinatura.findUnique({
      where: { id_assinatura: dto.id_assinatura },
    });
    if (!assinatura) {
      throw new NotFoundException('Assinatura não encontrada');
    }
    if (assinatura.origem === OrigemAssinatura.ASAAS) {
      throw new ConflictException(
        'Os pagamentos de assinaturas contratadas pelo Asaas são gerenciados pelo gateway e não podem ser registrados manualmente',
      );
    }

    const vencimento = lerData(dto.data_vencimento, 'data_vencimento');
    const situacao = dto.situacao ?? SituacaoPagamento.PENDENTE;
    const dataPagamento = this.resolverDataPagamento(situacao, dto.data_pagamento);

    // Evita lançar duas vezes a mesma cobrança (ex.: duplo clique)
    const duplicado = await this.prisma.pagamento.findFirst({
      where: { id_assinatura: dto.id_assinatura, data_vencimento: vencimento },
    });
    if (duplicado) {
      throw new ConflictException(
        'Já existe um pagamento dessa assinatura com esse vencimento',
      );
    }

    const criado = await this.prisma.pagamento.create({
      data: {
        id_assinatura: dto.id_assinatura,
        valor: dto.valor,
        data_vencimento: vencimento,
        data_pagamento: dataPagamento,
        situacao,
      },
      include: INCLUIR_COMPLETO,
    });
    return this.serializar(criado);
  }

  // HU54: atualizar a situação (pago, pendente ou vencido)
  async atualizarSituacao(id: string, dto: AtualizarSituacaoPagamentoDto) {
    const pagamento = await this.obter(id);

    if (pagamento.asaas_payment_id) {
      throw new ConflictException(
        'Este pagamento é gerenciado pelo Asaas e não pode ser alterado manualmente',
      );
    }
    if (pagamento.situacao === dto.situacao) {
      throw new BadRequestException('O pagamento já está nessa situação');
    }

    const dataPagamento = this.resolverDataPagamento(dto.situacao, dto.data_pagamento);

    const atualizado = await this.prisma.pagamento.update({
      where: { id_pagamento: id },
      data: { situacao: dto.situacao, data_pagamento: dataPagamento },
      include: INCLUIR_COMPLETO,
    });
    return this.serializar(atualizado);
  }
}