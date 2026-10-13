import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CriarDespesaDto } from './dto/criar-despesa.dto';
import { AtualizarDespesaDto } from './dto/atualizar-despesa.dto';

@Injectable()
export class DespesasService {
  constructor(private readonly prisma: PrismaService) {}

  // DESPESA não tem id_usuario direto - a posse é garantida pelo veículo.
  // Veículo removido (ativo = false) não pode receber novos lançamentos.
  private async validarVeiculo(usuarioId: string, id_veiculo: string) {
    const veiculo = await this.prisma.veiculo.findFirst({
      where: { id_veiculo, id_usuario: usuarioId, ativo: true },
    });
    if (!veiculo) {
      throw new NotFoundException('Veículo não encontrado ou removido');
    }
  }

  // A categoria precisa ser padrão do sistema (id_usuario nulo) ou personalizada do próprio usuário
  private async validarCategoria(usuarioId: string, id_categoria: string) {
    const categoria = await this.prisma.categoriaDespesa.findFirst({
      where: {
        id_categoria,
        OR: [{ id_usuario: null }, { id_usuario: usuarioId }],
      },
    });
    if (!categoria) {
      throw new NotFoundException('Categoria não encontrada');
    }
  }

  // HU18: toda despesa tem veículo do usuário + categoria, valor > 0 (DTO valida) e data
  async create(usuarioId: string, dto: CriarDespesaDto) {
    await Promise.all([
      this.validarVeiculo(usuarioId, dto.id_veiculo),
      this.validarCategoria(usuarioId, dto.id_categoria),
    ]);

    return this.prisma.despesa.create({
      data: {
        id_veiculo: dto.id_veiculo,
        id_categoria: dto.id_categoria,
        valor: dto.valor,
        data: new Date(dto.data),
      },
    });
  }

  async findAll(usuarioId: string) {
    return this.prisma.despesa.findMany({
      where: { veiculo: { id_usuario: usuarioId } },
      include: { veiculo: true, categoria: true },
      orderBy: { data: 'desc' },
    });
  }

  async findOne(usuarioId: string, id: string) {
    const despesa = await this.prisma.despesa.findFirst({
      where: { id_despesa: id, veiculo: { id_usuario: usuarioId } },
      include: { veiculo: true, categoria: true },
    });
    if (!despesa) {
      throw new NotFoundException('Despesa não encontrada');
    }
    return despesa;
  }

  // HU19: só valida veículo/categoria se eles realmente mudaram
  async update(usuarioId: string, id: string, dto: AtualizarDespesaDto) {
    const despesaAtual = await this.findOne(usuarioId, id);

    if (dto.id_veiculo && dto.id_veiculo !== despesaAtual.id_veiculo) {
      await this.validarVeiculo(usuarioId, dto.id_veiculo);
    }
    if (dto.id_categoria && dto.id_categoria !== despesaAtual.id_categoria) {
      await this.validarCategoria(usuarioId, dto.id_categoria);
    }

    return this.prisma.despesa.update({
      where: { id_despesa: id },
      data: {
        ...(dto.id_veiculo && { id_veiculo: dto.id_veiculo }),
        ...(dto.id_categoria && { id_categoria: dto.id_categoria }),
        ...(dto.valor !== undefined && { valor: dto.valor }),
        ...(dto.data && { data: new Date(dto.data) }),
      },
    });
  }

  // HU20: exclusão física (mesma lógica do Ganho - a despesa é o próprio dado financeiro)
  async remove(usuarioId: string, id: string) {
    await this.findOne(usuarioId, id);
    await this.prisma.despesa.delete({ where: { id_despesa: id } });
    return { mensagem: 'Despesa removida com sucesso' };
  }
}