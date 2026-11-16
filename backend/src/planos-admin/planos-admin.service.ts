import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, SituacaoAssinatura } from '@prisma/client';
import type { Plano } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { mesesDoPeriodo } from '../common/periodo-cobranca';
import { CriarPlanoDto } from './dto/criar-plano.dto';
import { AtualizarPlanoDto } from './dto/atualizar-plano.dto';

export interface ContagemAssinaturas {
  total: number;
  emAberto: number; // ativas + suspensas
}

// RF16: o administrador mantém os planos que o motorista vê no RF12.
// Não existe exclusão: plano só se inativa (HU47), para preservar as assinaturas existentes.
@Injectable()
export class PlanosAdminService {
  constructor(private readonly prisma: PrismaService) {}

  // Quantas assinaturas cada plano tem (para a tela avisar o que uma alteração afeta)
  private async contarAssinaturas(ids?: string[]) {
    const grupos = await this.prisma.assinatura.groupBy({
      by: ['id_plano', 'situacao'],
      _count: { _all: true },
      where: ids ? { id_plano: { in: ids } } : undefined,
    });

    const mapa = new Map<string, ContagemAssinaturas>();
    for (const grupo of grupos) {
      const atual = mapa.get(grupo.id_plano) ?? { total: 0, emAberto: 0 };
      atual.total += grupo._count._all;
      if (
        grupo.situacao === SituacaoAssinatura.ATIVA ||
        grupo.situacao === SituacaoAssinatura.SUSPENSA
      ) {
        atual.emAberto += grupo._count._all;
      }
      mapa.set(grupo.id_plano, atual);
    }
    return mapa;
  }

  private serializar(plano: Plano, contagem?: ContagemAssinaturas) {
    return {
      id_plano: plano.id_plano,
      nome: plano.nome,
      valor: Number(plano.valor),
      periodo_cobranca: plano.periodo_cobranca,
      beneficios: plano.beneficios,
      ativo: plano.ativo,
      data_cadastro: plano.data_cadastro.toISOString(),
      data_atualizacao: plano.data_atualizacao.toISOString(),
      total_assinaturas: contagem?.total ?? 0,
      assinaturas_em_aberto: contagem?.emAberto ?? 0,
    };
  }

  private async obter(id: string) {
    const plano = await this.prisma.plano.findUnique({ where: { id_plano: id } });
    if (!plano) {
      throw new NotFoundException('Plano não encontrado');
    }
    return plano;
  }

  // Nome de plano único (sem diferenciar maiúsculas de minúsculas)
  private async validarNomeLivre(nome: string, ignorarId?: string) {
    const existente = await this.prisma.plano.findFirst({
      where: {
        nome: { equals: nome, mode: 'insensitive' },
        ...(ignorarId && { id_plano: { not: ignorarId } }),
      },
    });
    if (existente) {
      throw new ConflictException('Já existe um plano com esse nome');
    }
  }

  // "Consultar plano": todos os planos, inclusive os inativos
  async listar() {
    const [planos, contagens] = await Promise.all([
      this.prisma.plano.findMany({ orderBy: [{ ativo: 'desc' }, { valor: 'asc' }] }),
      this.contarAssinaturas(),
    ]);
    return planos.map((p) => this.serializar(p, contagens.get(p.id_plano)));
  }

  async buscarUm(id: string) {
    const plano = await this.obter(id);
    const contagens = await this.contarAssinaturas([id]);
    return this.serializar(plano, contagens.get(id));
  }

  // HU45: valor > 0, nome, período e benefícios obrigatórios (o DTO valida o formato).
  // O plano nasce ativo.
  async criar(dto: CriarPlanoDto) {
    const nome = dto.nome.trim();
    const beneficios = dto.beneficios.trim();
    if (!nome || !beneficios) {
      throw new BadRequestException('Nome e benefícios são obrigatórios');
    }
    await this.validarNomeLivre(nome);

    const criado = await this.prisma.plano.create({
      data: {
        nome,
        valor: dto.valor,
        periodo_cobranca: dto.periodo_cobranca,
        beneficios,
      },
    });
    return this.serializar(criado);
  }

  // HU46: editar. Não mexe em nenhuma assinatura, então o histórico delas é preservado.
  // O período de cobrança não muda se o plano já tem assinaturas, porque os vencimentos delas
  // já foram calculados com ele; nesse caso o caminho é criar um novo plano e inativar este.
  async atualizar(id: string, dto: AtualizarPlanoDto) {
    const atual = await this.obter(id);

    if (
      dto.nome === undefined &&
      dto.valor === undefined &&
      dto.periodo_cobranca === undefined &&
      dto.beneficios === undefined
    ) {
      throw new BadRequestException('Informe ao menos um campo para alterar');
    }

    const dados: Prisma.PlanoUpdateInput = {};

    if (dto.nome !== undefined) {
      const nome = dto.nome.trim();
      if (!nome) {
        throw new BadRequestException('O nome do plano é obrigatório');
      }
      await this.validarNomeLivre(nome, id);
      dados.nome = nome;
    }

    if (dto.beneficios !== undefined) {
      const beneficios = dto.beneficios.trim();
      if (!beneficios) {
        throw new BadRequestException('Informe as características e benefícios do plano');
      }
      dados.beneficios = beneficios;
    }

    if (dto.valor !== undefined) {
      dados.valor = dto.valor; // vale para as próximas cobranças; pagamentos já lançados guardam o próprio valor
    }

    if (
      dto.periodo_cobranca !== undefined &&
      dto.periodo_cobranca !== atual.periodo_cobranca.trim().toUpperCase()
    ) {
      const periodoAtualValido = mesesDoPeriodo(atual.periodo_cobranca) !== null;
      const contagem = (await this.contarAssinaturas([id])).get(id);
      if (periodoAtualValido && contagem && contagem.total > 0) {
        throw new ConflictException(
          'Este plano já possui assinaturas. Para mudar o período de cobrança, crie um novo plano e inative este',
        );
      }
      dados.periodo_cobranca = dto.periodo_cobranca;
    }

    const atualizado = await this.prisma.plano.update({
      where: { id_plano: id },
      data: dados,
    });
    const contagens = await this.contarAssinaturas([id]);
    return this.serializar(atualizado, contagens.get(id));
  }

  private async alterarAtivo(id: string, ativo: boolean) {
    const atualizado = await this.prisma.plano.update({
      where: { id_plano: id },
      data: { ativo },
    });
    const contagens = await this.contarAssinaturas([id]);
    return this.serializar(atualizado, contagens.get(id));
  }

  // HU47
  async ativar(id: string) {
    const plano = await this.obter(id);
    if (plano.ativo) {
      throw new BadRequestException('O plano já está ativo');
    }
    if (mesesDoPeriodo(plano.periodo_cobranca) === null) {
      throw new BadRequestException(
        'O período de cobrança deste plano é inválido. Edite o plano antes de ativá-lo',
      );
    }
    return this.alterarAtivo(id, true);
  }

  // HU47: inativar impede NOVAS contratações (o POST /assinaturas já recusa plano inativo)
  // e não mexe nas assinaturas existentes.
  async inativar(id: string) {
    const plano = await this.obter(id);
    if (!plano.ativo) {
      throw new BadRequestException('O plano já está inativo');
    }
    return this.alterarAtivo(id, false);
  }
}