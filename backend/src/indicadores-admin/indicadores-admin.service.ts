import { BadRequestException, Injectable } from '@nestjs/common';
import {
  Prisma,
  SituacaoAssinatura,
  SituacaoPagamento,
  TipoUsuario,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ConsultarIndicadoresAdminDto } from './dto/consultar-indicadores-admin.dto';

const LIMITE_DIAS = 366;
const MS_DIA = 24 * 60 * 60 * 1000;

const dia = (data: Date) => data.toISOString().slice(0, 10);

// Lê 'AAAA-MM-DD' como data (UTC) e recusa datas que não existem (ex.: 2026-02-30)
function lerData(texto: string, campo: string): Date {
  const data = new Date(`${texto}T00:00:00.000Z`);
  if (Number.isNaN(data.getTime()) || dia(data) !== texto) {
    throw new BadRequestException(`${campo} é uma data inválida`);
  }
  return data;
}

interface Faixa {
  inicioTexto: string;
  fimTexto: string;
  // Para colunas DATE (vencimento e pagamento)
  inicioData: Date;
  fimData: Date;
  // Para colunas de data e hora (cadastro): do início do 1º dia ao início do dia seguinte ao último
  inicioTs: Date;
  fimTsExclusivo: Date;
}

// RF19: indicadores administrativos (HU55) com filtro por período (HU56).
// Só lê dados; não altera nada. Quando há período, "pertencer ao período" significa:
//  - usuários e assinaturas: terem sido cadastrados no período;
//  - pagamentos pendentes, vencidos e cancelados: terem vencimento no período;
//  - pagamentos pagos e receita: terem sido pagos (data do pagamento) no período.
@Injectable()
export class IndicadoresAdminService {
  constructor(private readonly prisma: PrismaService) {}

  // Sem período devolve null (todos os registros). Com período, valida (HU56).
  private resolverPeriodo(filtro: ConsultarIndicadoresAdminDto): Faixa | null {
    const { inicio, fim } = filtro;
    if (!inicio && !fim) {
      return null;
    }
    if (!inicio || !fim) {
      throw new BadRequestException('Informe inicio e fim juntos');
    }

    const inicioData = lerData(inicio, 'inicio');
    const fimData = lerData(fim, 'fim');
    if (fimData.getTime() < inicioData.getTime()) {
      throw new BadRequestException('A data inicial não pode ser posterior à data final');
    }
    const dias = (fimData.getTime() - inicioData.getTime()) / MS_DIA + 1;
    if (dias > LIMITE_DIAS) {
      throw new BadRequestException(`O período máximo é de ${LIMITE_DIAS} dias`);
    }

    const [ai, mi, di] = inicio.split('-').map(Number);
    const [af, mf, df] = fim.split('-').map(Number);
    return {
      inicioTexto: inicio,
      fimTexto: fim,
      inicioData,
      fimData,
      inicioTs: new Date(ai, mi - 1, di),
      fimTsExclusivo: new Date(af, mf - 1, df + 1),
    };
  }

  // Quantidade e valor de pagamentos de uma situação
  private async somar(
    situacao: SituacaoPagamento,
    campo: 'data_vencimento' | 'data_pagamento',
    faixa: Faixa | null,
  ) {
    const periodo = faixa ? { gte: faixa.inicioData, lte: faixa.fimData } : undefined;
    const where: Prisma.PagamentoWhereInput =
      campo === 'data_vencimento'
        ? { situacao, data_vencimento: periodo }
        : { situacao, data_pagamento: periodo };

    const resultado = await this.prisma.pagamento.aggregate({
      where,
      _count: { _all: true },
      _sum: { valor: true },
    });
    return {
      quantidade: resultado._count._all,
      valor: Number(resultado._sum.valor ?? 0),
    };
  }

  // Receita por mês (só pagamentos pagos), com os meses sem receita zerados
  private receitaMensal(
    pagos: { data_pagamento: Date | null; valor: Prisma.Decimal }[],
    faixa: Faixa | null,
  ) {
    const porMes = new Map<string, number>();
    for (const pago of pagos) {
      if (!pago.data_pagamento) continue;
      const mes = dia(pago.data_pagamento).slice(0, 7);
      porMes.set(mes, (porMes.get(mes) ?? 0) + Number(pago.valor));
    }

    let primeiroMes: string;
    let ultimoMes: string;
    if (faixa) {
      primeiroMes = faixa.inicioTexto.slice(0, 7);
      ultimoMes = faixa.fimTexto.slice(0, 7);
    } else {
      const meses = [...porMes.keys()].sort();
      if (meses.length === 0) {
        return [];
      }
      const hoje = new Date();
      const mesAtual = `${hoje.getFullYear()}-${String(hoje.getMonth() + 1).padStart(2, '0')}`;
      primeiroMes = meses[0];
      ultimoMes = meses[meses.length - 1] > mesAtual ? meses[meses.length - 1] : mesAtual;
    }

    const resultado: { mes: string; receita: number }[] = [];
    let [ano, mes] = primeiroMes.split('-').map(Number);
    const [anoFinal, mesFinal] = ultimoMes.split('-').map(Number);
    while (ano < anoFinal || (ano === anoFinal && mes <= mesFinal)) {
      const chave = `${ano}-${String(mes).padStart(2, '0')}`;
      resultado.push({
        mes: chave,
        receita: Math.round((porMes.get(chave) ?? 0) * 100) / 100,
      });
      mes += 1;
      if (mes > 12) {
        mes = 1;
        ano += 1;
      }
    }
    return resultado;
  }

  async obter(filtro: ConsultarIndicadoresAdminDto) {
    const faixa = this.resolverPeriodo(filtro);
    const cadastradoNoPeriodo = faixa
      ? { gte: faixa.inicioTs, lt: faixa.fimTsExclusivo }
      : undefined;

    const [
      usuarios,
      gruposAssinaturas,
      pendentes,
      vencidos,
      cancelados,
      pagos,
      pagosParaGrafico,
    ] = await Promise.all([
      // "Usuários cadastrados" = motoristas (os administradores não contam)
      this.prisma.usuario.count({
        where: { tipo_usuario: TipoUsuario.MOTORISTA, data_cadastro: cadastradoNoPeriodo },
      }),
      this.prisma.assinatura.groupBy({
        by: ['situacao'],
        _count: { _all: true },
        where: { data_cadastro: cadastradoNoPeriodo },
      }),
      this.somar(SituacaoPagamento.PENDENTE, 'data_vencimento', faixa),
      this.somar(SituacaoPagamento.VENCIDO, 'data_vencimento', faixa),
      this.somar(SituacaoPagamento.CANCELADO, 'data_vencimento', faixa),
      this.somar(SituacaoPagamento.PAGO, 'data_pagamento', faixa),
      this.prisma.pagamento.findMany({
        where: {
          situacao: SituacaoPagamento.PAGO,
          data_pagamento: faixa ? { gte: faixa.inicioData, lte: faixa.fimData } : undefined,
        },
        select: { data_pagamento: true, valor: true },
      }),
    ]);

    const contar = (situacao: SituacaoAssinatura) =>
      gruposAssinaturas.find((g) => g.situacao === situacao)?._count._all ?? 0;

    const assinaturas = {
      pendentes: contar(SituacaoAssinatura.PENDENTE),
      ativas: contar(SituacaoAssinatura.ATIVA),
      suspensas: contar(SituacaoAssinatura.SUSPENSA),
      canceladas: contar(SituacaoAssinatura.CANCELADA),
    };

    return {
      periodo: faixa ? { inicio: faixa.inicioTexto, fim: faixa.fimTexto } : null,
      usuarios: { total: usuarios },
      assinaturas: {
        total:
          assinaturas.pendentes +
          assinaturas.ativas +
          assinaturas.suspensas +
          assinaturas.canceladas,
        ...assinaturas,
      },
      pagamentos: { pendentes, vencidos, pagos, cancelados },
      receita_registrada: pagos.valor,
      receita_mensal: this.receitaMensal(pagosParaGrafico, faixa),
    };
  }
}