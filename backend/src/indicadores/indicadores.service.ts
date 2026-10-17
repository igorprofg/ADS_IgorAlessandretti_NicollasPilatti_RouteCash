import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ConsultaIndicadoresDto } from './dto/consulta-indicadores.dto';

const arredondar = (n: number) => Math.round(n * 100) / 100;

// RN37: nunca dividir por zero - sem horas/km no período o indicador vem como null
const dividir = (a: number, b: number) => (b > 0 ? arredondar(a / b) : null);

@Injectable()
export class IndicadoresService {
  constructor(private readonly prisma: PrismaService) {}

  // Data de hoje (do servidor) no formato AAAA-MM-DD
  private hoje() {
    const agora = new Date();
    const mm = String(agora.getMonth() + 1).padStart(2, '0');
    const dd = String(agora.getDate()).padStart(2, '0');
    return `${agora.getFullYear()}-${mm}-${dd}`;
  }

  // HU30: padrão = dia atual; inicial e final precisam vir juntas; final não pode ser anterior à inicial
  private resolverPeriodo(filtro: ConsultaIndicadoresDto) {
    if (Boolean(filtro.inicio) !== Boolean(filtro.fim)) {
      throw new BadRequestException(
        'Informe a data inicial e a data final juntas',
      );
    }
    const inicio = filtro.inicio ?? this.hoje();
    const fim = filtro.fim ?? this.hoje();

    if (fim < inicio) {
      throw new BadRequestException(
        'A data final não pode ser anterior à data inicial',
      );
    }
    return { inicio, fim };
  }

  // Converte AAAA-MM-DD em Date UTC (colunas DATE de ganho/despesa), recusando datas inexistentes
  private dataUtc(dia: string) {
    const d = new Date(`${dia}T00:00:00.000Z`);
    if (Number.isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== dia) {
      throw new BadRequestException(`Data inválida: ${dia}`);
    }
    return d;
  }

  // Limites do período em horário local do servidor (jornada guarda timestamp, não só data)
  private limitesLocais(inicio: string, fim: string) {
    const [yi, mi, di] = inicio.split('-').map(Number);
    const [yf, mf, df] = fim.split('-').map(Number);
    return {
      de: new Date(yi, mi - 1, di, 0, 0, 0, 0), // 00:00 do primeiro dia
      ate: new Date(yf, mf - 1, df + 1, 0, 0, 0, 0), // 00:00 do dia seguinte ao último (exclusivo)
    };
  }

  // HU28: indicadores calculados na hora, a partir dos lançamentos do período
  // HU29: como nada fica guardado em cache, qualquer edição/exclusão de ganho, despesa,
  // jornada ou quilometragem já aparece no próximo cálculo (recálculo automático por construção)
  async calcular(usuarioId: string, filtro: ConsultaIndicadoresDto) {
    const { inicio, fim } = this.resolverPeriodo(filtro);
    const dataDe = this.dataUtc(inicio);
    const dataAte = this.dataUtc(fim);
    const { de, ate } = this.limitesLocais(inicio, fim);

    const [ganhos, despesas, jornadas] = await Promise.all([
      this.prisma.ganho.aggregate({
        _sum: { valor: true },
        where: {
          veiculo: { id_usuario: usuarioId },
          data: { gte: dataDe, lte: dataAte },
        },
      }),
      this.prisma.despesa.aggregate({
        _sum: { valor: true },
        where: {
          veiculo: { id_usuario: usuarioId },
          data: { gte: dataDe, lte: dataAte },
        },
      }),
      this.prisma.jornada.findMany({
        where: { id_usuario: usuarioId, inicio: { gte: de, lt: ate } },
        select: { inicio: true, fim: true, km_rodados: true },
      }),
    ]);

    const faturamento = Number(ganhos._sum.valor ?? 0); // RN32
    const totalDespesas = Number(despesas._sum.valor ?? 0); // RN33
    const lucroLiquido = faturamento - totalDespesas; // RN34

    // Horas: só jornadas finalizadas. Km: de todas as jornadas do período que tenham km registrado
    let minutos = 0;
    let km = 0;
    for (const j of jornadas) {
      if (j.fim) minutos += (j.fim.getTime() - j.inicio.getTime()) / 60000;
      if (j.km_rodados !== null) km += Number(j.km_rodados);
    }
    const horas = minutos / 60;

    return {
      periodo: { inicio, fim },
      faturamento: arredondar(faturamento),
      despesas: arredondar(totalDespesas),
      lucro_liquido: arredondar(lucroLiquido),
      horas_trabalhadas: arredondar(horas),
      km_rodados: arredondar(km),
      ganho_por_hora: dividir(lucroLiquido, horas), // RN35
      ganho_por_km: dividir(lucroLiquido, km), // RN36
      custo_por_km: dividir(totalDespesas, km),
    };
  }
}