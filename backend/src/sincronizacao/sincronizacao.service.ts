import { Injectable, Logger } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { EnviarSincronizacaoDto } from './dto/enviar-sincronizacao.dto';
import { GanhoSincronizadoDto } from './dto/ganho-sincronizado.dto';
import { DespesaSincronizadaDto } from './dto/despesa-sincronizada.dto';
import { JornadaSincronizadaDto } from './dto/jornada-sincronizada.dto';
import { ExclusaoSincronizadaDto } from './dto/exclusao-sincronizada.dto';
import { VeiculoSincronizadoDto } from './dto/veiculo-sincronizado.dto';
import { PlataformaSincronizadaDto } from './dto/plataforma-sincronizada.dto';

// Tolerância para diferença de relógio entre o celular e o servidor
const TOLERANCIA_MS = 5 * 60 * 1000;

export type Status = 'ok' | 'ignorado' | 'erro';

export interface ResultadoItem {
  status: Status;
  acao?: 'criado' | 'atualizado' | 'excluido';
  codigo?: string;
  motivo?: string;
}

export interface Resultado extends ResultadoItem {
  entidade: string;
  id: string | null;
}

// Erro "esperado" de um item (vira status "erro" só para aquele item)
class ErroItem extends Error {
  constructor(
    public readonly codigo: string,
    mensagem: string,
  ) {
    super(mensagem);
  }
}

@Injectable()
export class SincronizacaoService {
  private readonly logger = new Logger(SincronizacaoService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ---------- utilitários ----------

  private lerDataHora(valor: string, campo: string) {
    const data = new Date(valor);
    if (Number.isNaN(data.getTime())) {
      throw new ErroItem('VALIDACAO', `${campo} inválido`);
    }
    return data;
  }

  // 'AAAA-MM-DD' -> Date UTC (coluna DATE), recusando datas inexistentes como 2026-02-31
  private lerDia(valor: string) {
    const data = new Date(`${valor}T00:00:00.000Z`);
    if (Number.isNaN(data.getTime()) || data.toISOString().slice(0, 10) !== valor) {
      throw new ErroItem('VALIDACAO', 'data inválida');
    }
    return data;
  }

  // Horário da alteração no app. Nunca pode ficar no futuro (relógio do celular errado)
  private lerAtualizadoEm(valor: string) {
    const data = this.lerDataHora(valor, 'atualizado_em');
    return new Date(Math.min(data.getTime(), Date.now()));
  }

  private validarNaoFuturo(data: Date, campo: string) {
    if (data.getTime() > Date.now() + TOLERANCIA_MS) {
      throw new ErroItem('VALIDACAO', `${campo} não pode estar no futuro`);
    }
  }

  // Conflito de edição: vence a alteração mais recente
  private versaoIgnorada(servidor: Date, app: Date): ResultadoItem | null {
    if (servidor.getTime() === app.getTime()) {
      return {
        status: 'ignorado',
        codigo: 'JA_SINCRONIZADO',
        motivo: 'Este registro já está sincronizado',
      };
    }
    if (servidor.getTime() > app.getTime()) {
      return {
        status: 'ignorado',
        codigo: 'SERVIDOR_MAIS_RECENTE',
        motivo: 'O servidor tem uma versão mais recente deste registro',
      };
    }
    return null;
  }

  private async veiculoValido(usuarioId: string, id_veiculo: string) {
    const veiculo = await this.prisma.veiculo.findFirst({
      where: { id_veiculo, id_usuario: usuarioId, ativo: true },
    });
    if (!veiculo) {
      throw new ErroItem('NAO_ENCONTRADO', 'Veículo não encontrado ou removido');
    }
  }

  private async plataformaValida(usuarioId: string, id_plataforma: string) {
    const plataforma = await this.prisma.plataforma.findFirst({
      where: { id_plataforma, id_usuario: usuarioId, ativa: true },
    });
    if (!plataforma) {
      throw new ErroItem('NAO_ENCONTRADO', 'Plataforma não encontrada ou inativa');
    }
  }

  private async categoriaValida(usuarioId: string, id_categoria: string) {
    const categoria = await this.prisma.categoriaDespesa.findFirst({
      where: {
        id_categoria,
        OR: [{ id_usuario: null }, { id_usuario: usuarioId }],
      },
    });
    if (!categoria) {
      throw new ErroItem('NAO_ENCONTRADO', 'Categoria não encontrada');
    }
  }

  // Mesma regra do JornadasService: jornadas do mesmo usuário não se sobrepõem
  // (jornada em andamento conta como "sem fim")
  private async semSobreposicao(
    usuarioId: string,
    inicio: Date,
    fim: Date | null,
    ignorarId: string,
  ) {
    const conflito = await this.prisma.jornada.findFirst({
      where: {
        id_usuario: usuarioId,
        id_jornada: { not: ignorarId },
        ...(fim && { inicio: { lt: fim } }),
        OR: [{ fim: null }, { fim: { gt: inicio } }],
      },
    });
    if (conflito) {
      throw new ErroItem(
        'CONFLITO',
        conflito.fim === null
          ? 'Já existe uma jornada em andamento'
          : 'Este horário se sobrepõe a outra jornada já registrada',
      );
    }
  }

  // Valida o item (classe + decorators) e converte qualquer falha em um resultado por item
  private async processar<T extends object>(
    entidade: string,
    bruto: Record<string, unknown>,
    campoId: string,
    classe: new () => T,
    aplicar: (item: T) => Promise<ResultadoItem>,
  ): Promise<Resultado> {
    const id = typeof bruto[campoId] === 'string' ? (bruto[campoId] as string) : null;

    try {
      const item = plainToInstance(classe, bruto);
      const erros = await validate(item, { whitelist: true });
      if (erros.length > 0) {
        const motivo = erros
          .flatMap((erro) => Object.values(erro.constraints ?? {}))
          .join('; ');
        return { entidade, id, status: 'erro', codigo: 'VALIDACAO', motivo };
      }
      return { entidade, id, ...(await aplicar(item)) };
    } catch (error) {
      if (error instanceof ErroItem) {
        return { entidade, id, status: 'erro', codigo: error.codigo, motivo: error.message };
      }
      // Erros do banco que se repetiriam sempre: não adianta o app tentar de novo
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        const conhecidos: Record<string, { codigo: string; motivo: string }> = {
          P2002: { codigo: 'CONFLITO', motivo: 'Já existe um registro com esses dados' },
          P2000: { codigo: 'VALIDACAO', motivo: 'Algum campo excede o tamanho permitido' },
          P2003: { codigo: 'NAO_ENCONTRADO', motivo: 'Registro relacionado não encontrado' },
        };
        const conhecido = conhecidos[error.code];
        if (conhecido) {
          return { entidade, id, status: 'erro', ...conhecido };
        }
      }
      this.logger.error(
        `Falha ao sincronizar ${entidade} ${id}`,
        error instanceof Error ? error.stack : String(error),
      );
      return {
        entidade,
        id,
        status: 'erro',
        codigo: 'ERRO_INTERNO',
        motivo: 'Falha inesperada ao processar o item',
      };
    }
  }

  // ---------- veículo ----------

  private async sincronizarVeiculo(
    usuarioId: string,
    item: VeiculoSincronizadoDto,
  ): Promise<ResultadoItem> {
    const existente = await this.prisma.veiculo.findUnique({
      where: { id_veiculo: item.id_veiculo },
    });
    if (existente && existente.id_usuario !== usuarioId) {
      throw new ErroItem('VALIDACAO', 'Identificador inválido');
    }

    const atualizadoEm = this.lerAtualizadoEm(item.atualizado_em);
    if (existente) {
      const ignorado = this.versaoIgnorada(existente.data_atualizacao, atualizadoEm);
      if (ignorado) return ignorado;
    }

    const marca = item.marca.trim();
    const modelo = item.modelo.trim();
    const combustivel = item.combustivel.trim();
    const placa = item.placa?.trim() || null;
    if (!marca || !modelo || !combustivel) {
      throw new ErroItem('VALIDACAO', 'Marca, modelo e combustível são obrigatórios');
    }

    // A placa é única no sistema
    if (placa) {
      const placaEmUso =
    placa
        ? await this.prisma.veiculo.findFirst({
            where: {
              id_usuario: usuarioId,
              placa,
              id_veiculo: {
                not: item.id_veiculo,
              },
            },
          })
        : null;

if (placaEmUso) {
  throw new ErroItem(
    'CONFLITO',
    placaEmUso.ativo
      ? 'Você já possui um veículo cadastrado com essa placa'
      : 'Você já possui um veículo inativo com essa placa',
  );
}
      if (placaEmUso) {
        throw new ErroItem('CONFLITO', 'Já existe um veículo cadastrado com essa placa');
      }
    }

    // Veículo inativo nunca é o principal (mesma regra da exclusão pela API)
    const principal = item.ativo && item.principal;

    const dados = {
      marca,
      modelo,
      ano: item.ano,
      combustivel,
      consumo_medio: item.consumo_medio,
      placa,
      ativo: item.ativo,
      principal,
      data_atualizacao: atualizadoEm,
    };

    // Só pode haver um veículo principal por usuário. Tudo na mesma transação:
    // se a gravação falhar, o principal anterior não se perde.
    const operacoes: Prisma.PrismaPromise<unknown>[] = [];
    if (principal) {
      operacoes.push(
        this.prisma.veiculo.updateMany({
          where: {
            id_usuario: usuarioId,
            id_veiculo: { not: item.id_veiculo },
            principal: true,
          },
          data: { principal: false },
        }),
      );
    }
    if (existente) {
      operacoes.push(
        this.prisma.veiculo.update({ where: { id_veiculo: item.id_veiculo }, data: dados }),
      );
    } else {
      operacoes.push(
        this.prisma.veiculo.create({
          data: { id_veiculo: item.id_veiculo, id_usuario: usuarioId, ...dados },
        }),
      );
    }
    await this.prisma.$transaction(operacoes);

    return { status: 'ok', acao: existente ? 'atualizado' : 'criado' };
  }

  // ---------- plataforma ----------

  private async sincronizarPlataforma(
    usuarioId: string,
    item: PlataformaSincronizadaDto,
  ): Promise<ResultadoItem> {
    const existente = await this.prisma.plataforma.findUnique({
      where: { id_plataforma: item.id_plataforma },
    });
    if (existente && existente.id_usuario !== usuarioId) {
      throw new ErroItem('VALIDACAO', 'Identificador inválido');
    }

    const atualizadoEm = this.lerAtualizadoEm(item.atualizado_em);
    if (existente) {
      const ignorado = this.versaoIgnorada(existente.data_atualizacao, atualizadoEm);
      if (ignorado) return ignorado;
    }

    const nome = item.nome.trim();
    if (!nome) {
      throw new ErroItem('VALIDACAO', 'O nome da plataforma é obrigatório');
    }

    // Plataforma padrão do sistema: só pode ser ativada/inativada (o nome não muda)
    if (existente?.padrao) {
      await this.prisma.plataforma.update({
        where: { id_plataforma: item.id_plataforma },
        data: { ativa: item.ativa, data_atualizacao: atualizadoEm },
      });
      return { status: 'ok', acao: 'atualizado' };
    }

    // Nome único por usuário (sem diferenciar maiúsculas de minúsculas)
    const duplicada = await this.prisma.plataforma.findFirst({
      where: {
        id_usuario: usuarioId,
        nome: { equals: nome, mode: 'insensitive' },
        id_plataforma: { not: item.id_plataforma },
      },
    });
    if (duplicada) {
      throw new ErroItem('CONFLITO', 'Já existe uma plataforma com esse nome');
    }

    if (existente) {
      await this.prisma.plataforma.update({
        where: { id_plataforma: item.id_plataforma },
        data: { nome, ativa: item.ativa, data_atualizacao: atualizadoEm },
      });
      return { status: 'ok', acao: 'atualizado' };
    }

    await this.prisma.plataforma.create({
      data: {
        id_plataforma: item.id_plataforma,
        id_usuario: usuarioId,
        nome,
        ativa: item.ativa,
        padrao: false,
        data_atualizacao: atualizadoEm,
      },
    });
    return { status: 'ok', acao: 'criado' };
  }

  // ---------- ganho ----------

  private async sincronizarGanho(
    usuarioId: string,
    item: GanhoSincronizadoDto,
  ): Promise<ResultadoItem> {
    const existente = await this.prisma.ganho.findUnique({
      where: { id_ganho: item.id_ganho },
      include: { veiculo: { select: { id_usuario: true } } },
    });
    if (existente && existente.veiculo.id_usuario !== usuarioId) {
      throw new ErroItem('VALIDACAO', 'Identificador inválido');
    }

    const atualizadoEm = this.lerAtualizadoEm(item.atualizado_em);
    if (existente) {
      const ignorado = this.versaoIgnorada(existente.data_atualizacao, atualizadoEm);
      if (ignorado) return ignorado;
    }

    const data = this.lerDia(item.data);
    if (!existente || existente.id_veiculo !== item.id_veiculo) {
      await this.veiculoValido(usuarioId, item.id_veiculo);
    }
    if (!existente || existente.id_plataforma !== item.id_plataforma) {
      await this.plataformaValida(usuarioId, item.id_plataforma);
    }

    const dados = {
      id_veiculo: item.id_veiculo,
      id_plataforma: item.id_plataforma,
      valor: item.valor,
      data,
      observacao: item.observacao?.trim() || null,
      data_atualizacao: atualizadoEm,
    };

    if (existente) {
      await this.prisma.ganho.update({ where: { id_ganho: item.id_ganho }, data: dados });
      return { status: 'ok', acao: 'atualizado' };
    }
    await this.prisma.ganho.create({ data: { id_ganho: item.id_ganho, ...dados } });
    return { status: 'ok', acao: 'criado' };
  }

  // ---------- despesa ----------

  private async sincronizarDespesa(
    usuarioId: string,
    item: DespesaSincronizadaDto,
  ): Promise<ResultadoItem> {
    const existente = await this.prisma.despesa.findUnique({
      where: { id_despesa: item.id_despesa },
      include: { veiculo: { select: { id_usuario: true } } },
    });
    if (existente && existente.veiculo.id_usuario !== usuarioId) {
      throw new ErroItem('VALIDACAO', 'Identificador inválido');
    }

    const atualizadoEm = this.lerAtualizadoEm(item.atualizado_em);
    if (existente) {
      const ignorado = this.versaoIgnorada(existente.data_atualizacao, atualizadoEm);
      if (ignorado) return ignorado;
    }

    const data = this.lerDia(item.data);
    if (!existente || existente.id_veiculo !== item.id_veiculo) {
      await this.veiculoValido(usuarioId, item.id_veiculo);
    }
    if (!existente || existente.id_categoria !== item.id_categoria) {
      await this.categoriaValida(usuarioId, item.id_categoria);
    }

    const dados = {
      id_veiculo: item.id_veiculo,
      id_categoria: item.id_categoria,
      valor: item.valor,
      data,
      observacao: item.observacao?.trim() || null,
      data_atualizacao: atualizadoEm,
    };

    if (existente) {
      await this.prisma.despesa.update({ where: { id_despesa: item.id_despesa }, data: dados });
      return { status: 'ok', acao: 'atualizado' };
    }
    await this.prisma.despesa.create({ data: { id_despesa: item.id_despesa, ...dados } });
    return { status: 'ok', acao: 'criado' };
  }

  // ---------- jornada (inclui a quilometragem, que é o campo km_rodados) ----------

  private async sincronizarJornada(
    usuarioId: string,
    item: JornadaSincronizadaDto,
  ): Promise<ResultadoItem> {
    const existente = await this.prisma.jornada.findUnique({
      where: { id_jornada: item.id_jornada },
    });
    if (existente && existente.id_usuario !== usuarioId) {
      throw new ErroItem('VALIDACAO', 'Identificador inválido');
    }

    const atualizadoEm = this.lerAtualizadoEm(item.atualizado_em);
    if (existente) {
      const ignorado = this.versaoIgnorada(existente.data_atualizacao, atualizadoEm);
      if (ignorado) return ignorado;
    }

    const inicio = this.lerDataHora(item.inicio, 'inicio');
    const fim = item.fim ? this.lerDataHora(item.fim, 'fim') : null;
    this.validarNaoFuturo(inicio, 'O horário de início');
    if (fim) this.validarNaoFuturo(fim, 'O horário final');
    if (fim && fim.getTime() <= inicio.getTime()) {
      throw new ErroItem(
        'VALIDACAO',
        'O horário final deve ser posterior ao horário de início',
      );
    }

    if (!existente || existente.id_veiculo !== item.id_veiculo) {
      await this.veiculoValido(usuarioId, item.id_veiculo);
    }
    await this.semSobreposicao(usuarioId, inicio, fim, item.id_jornada);

    const dados = {
      id_veiculo: item.id_veiculo,
      inicio,
      fim,
      km_rodados: item.km_rodados ?? null,
      data_atualizacao: atualizadoEm,
    };

    if (existente) {
      await this.prisma.jornada.update({ where: { id_jornada: item.id_jornada }, data: dados });
      return { status: 'ok', acao: 'atualizado' };
    }
    await this.prisma.jornada.create({
      data: { id_jornada: item.id_jornada, id_usuario: usuarioId, ...dados },
    });
    return { status: 'ok', acao: 'criado' };
  }

  // ---------- exclusões ----------

  // Excluir é idempotente: se o registro já não existe, vira "ignorado" (o app tira da fila)
  private async excluir(
    usuarioId: string,
    item: ExclusaoSincronizadaDto,
  ): Promise<ResultadoItem> {
    let removidos = 0;

    if (item.entidade === 'ganho') {
      ({ count: removidos } = await this.prisma.ganho.deleteMany({
        where: { id_ganho: item.id, veiculo: { id_usuario: usuarioId } },
      }));
    } else if (item.entidade === 'despesa') {
      ({ count: removidos } = await this.prisma.despesa.deleteMany({
        where: { id_despesa: item.id, veiculo: { id_usuario: usuarioId } },
      }));
    } else {
      ({ count: removidos } = await this.prisma.jornada.deleteMany({
        where: { id_jornada: item.id, id_usuario: usuarioId },
      }));
    }

    if (removidos === 0) {
      return {
        status: 'ignorado',
        codigo: 'JA_SINCRONIZADO',
        motivo: 'O registro não existe no servidor',
      };
    }
    return { status: 'ok', acao: 'excluido' };
  }

  // ---------- RF11: app -> servidor ----------

  async enviar(usuarioId: string, dto: EnviarSincronizacaoDto) {
    const resultados: Resultado[] = [];

    // Ordem: veículos e plataformas primeiro, pra um lançamento poder referenciar
    // um veículo/plataforma criado offline no mesmo lote
    for (const bruto of dto.veiculos ?? []) {
      resultados.push(
        await this.processar('veiculo', bruto, 'id_veiculo', VeiculoSincronizadoDto, (item) =>
          this.sincronizarVeiculo(usuarioId, item),
        ),
      );
    }

    for (const bruto of dto.plataformas ?? []) {
      resultados.push(
        await this.processar(
          'plataforma',
          bruto,
          'id_plataforma',
          PlataformaSincronizadaDto,
          (item) => this.sincronizarPlataforma(usuarioId, item),
        ),
      );
    }

    for (const bruto of dto.ganhos ?? []) {
      resultados.push(
        await this.processar('ganho', bruto, 'id_ganho', GanhoSincronizadoDto, (item) =>
          this.sincronizarGanho(usuarioId, item),
        ),
      );
    }

    for (const bruto of dto.despesas ?? []) {
      resultados.push(
        await this.processar('despesa', bruto, 'id_despesa', DespesaSincronizadaDto, (item) =>
          this.sincronizarDespesa(usuarioId, item),
        ),
      );
    }

    // Em ordem de início, pra checagem de sobreposição ser previsível
    const tempo = (x: Record<string, unknown>) => Date.parse(String(x.inicio)) || 0;
    const jornadas = [...(dto.jornadas ?? [])].sort((a, b) => tempo(a) - tempo(b));
    for (const bruto of jornadas) {
      resultados.push(
        await this.processar('jornada', bruto, 'id_jornada', JornadaSincronizadaDto, (item) =>
          this.sincronizarJornada(usuarioId, item),
        ),
      );
    }

    // Exclusões por último: se um id vier como alteração e como exclusão, a exclusão prevalece
    for (const bruto of dto.exclusoes ?? []) {
      const resultado = await this.processar(
        'exclusao',
        bruto,
        'id',
        ExclusaoSincronizadaDto,
        (item) => this.excluir(usuarioId, item),
      );
      resultados.push({
        ...resultado,
        entidade: typeof bruto.entidade === 'string' ? bruto.entidade : 'exclusao',
      });
    }

    return { sincronizado_em: new Date().toISOString(), resultados };
  }

  // ---------- RF11: servidor -> app (retrato completo do usuário) ----------

  async baixar(usuarioId: string) {
    const [veiculos, plataformas, categorias, ganhos, despesas, jornadas] =
      await Promise.all([
        this.prisma.veiculo.findMany({
          where: { id_usuario: usuarioId },
          orderBy: { data_cadastro: 'asc' },
        }),
        this.prisma.plataforma.findMany({
          where: { id_usuario: usuarioId },
          orderBy: [{ padrao: 'desc' }, { nome: 'asc' }],
        }),
        this.prisma.categoriaDespesa.findMany({
          where: { OR: [{ id_usuario: null }, { id_usuario: usuarioId }] },
          orderBy: { nome: 'asc' },
        }),
        this.prisma.ganho.findMany({
          where: { veiculo: { id_usuario: usuarioId } },
          orderBy: { data: 'desc' },
        }),
        this.prisma.despesa.findMany({
          where: { veiculo: { id_usuario: usuarioId } },
          orderBy: { data: 'desc' },
        }),
        this.prisma.jornada.findMany({
          where: { id_usuario: usuarioId },
          orderBy: { inicio: 'desc' },
        }),
      ]);

    // Valores decimais saem como número e datas (DATE) como AAAA-MM-DD, pra facilitar o app
    return {
      sincronizado_em: new Date().toISOString(),
      veiculos: veiculos.map((v) => ({ ...v, consumo_medio: Number(v.consumo_medio) })),
      plataformas,
      categorias_despesa: categorias,
      ganhos: ganhos.map((g) => ({
        ...g,
        valor: Number(g.valor),
        data: g.data.toISOString().slice(0, 10),
      })),
      despesas: despesas.map((d) => ({
        ...d,
        valor: Number(d.valor),
        data: d.data.toISOString().slice(0, 10),
      })),
      jornadas: jornadas.map((j) => ({
        ...j,
        km_rodados: j.km_rodados === null ? null : Number(j.km_rodados),
      })),
    };
  }
}