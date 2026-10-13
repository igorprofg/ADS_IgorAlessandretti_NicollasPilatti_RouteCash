import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CriarGanhoDto } from './dto/criar-ganho.dto';
import { AtualizarGanhoDto } from './dto/atualizar-ganho.dto';
import { DuplicarGanhoDto } from './dto/duplicar-ganho.dto';

@Injectable()
export class GanhosService {
  constructor(private readonly prisma: PrismaService) {}

  // RN29: GANHO não tem id_usuario direto - a posse é garantida pelo veículo.
  // Veículo removido (ativo = false) não pode receber novos lançamentos.
  private async validarVeiculo(usuarioId: string, id_veiculo: string) {
    const veiculo = await this.prisma.veiculo.findFirst({
      where: { id_veiculo, id_usuario: usuarioId, ativo: true },
    });
    if (!veiculo) {
      throw new NotFoundException('Veículo não encontrado ou removido');
    }
  }

  // RN26: plataforma inativa não pode receber novos registros de ganho
  private async validarPlataforma(usuarioId: string, id_plataforma: string) {
    const plataforma = await this.prisma.plataforma.findFirst({
      where: { id_plataforma, id_usuario: usuarioId, ativa: true },
    });
    if (!plataforma) {
      throw new NotFoundException('Plataforma não encontrada ou inativa');
    }
  }

  // RN27/RN28: valor > 0 (DTO valida) e ganho precisa de data e plataforma
  async create(usuarioId: string, dto: CriarGanhoDto) {
    await Promise.all([
      this.validarVeiculo(usuarioId, dto.id_veiculo),
      this.validarPlataforma(usuarioId, dto.id_plataforma),
    ]);

    return this.prisma.ganho.create({
      data: {
        id_veiculo: dto.id_veiculo,
        id_plataforma: dto.id_plataforma,
        valor: dto.valor,
        data: new Date(dto.data),
      },
    });
  }

  async findAll(usuarioId: string) {
    return this.prisma.ganho.findMany({
      where: { veiculo: { id_usuario: usuarioId } },
      include: { veiculo: true, plataforma: true },
      orderBy: { data: 'desc' },
    });
  }

  async findOne(usuarioId: string, id: string) {
    const ganho = await this.prisma.ganho.findFirst({
      where: { id_ganho: id, veiculo: { id_usuario: usuarioId } },
      include: { veiculo: true, plataforma: true },
    });
    if (!ganho) {
      throw new NotFoundException('Ganho não encontrado');
    }
    return ganho;
  }

  // HU15: só valida veículo/plataforma se eles realmente mudaram
  // (assim dá pra corrigir só o valor de um ganho antigo cuja plataforma já foi inativada)
  async update(usuarioId: string, id: string, dto: AtualizarGanhoDto) {
    const ganhoAtual = await this.findOne(usuarioId, id);

    if (dto.id_veiculo && dto.id_veiculo !== ganhoAtual.id_veiculo) {
      await this.validarVeiculo(usuarioId, dto.id_veiculo);
    }
    if (dto.id_plataforma && dto.id_plataforma !== ganhoAtual.id_plataforma) {
      await this.validarPlataforma(usuarioId, dto.id_plataforma);
    }

    return this.prisma.ganho.update({
      where: { id_ganho: id },
      data: {
        ...(dto.id_veiculo && { id_veiculo: dto.id_veiculo }),
        ...(dto.id_plataforma && { id_plataforma: dto.id_plataforma }),
        ...(dto.valor !== undefined && { valor: dto.valor }),
        ...(dto.data && { data: new Date(dto.data) }),
      },
    });
  }

  // HU16: exclusão física - o ganho É o dado financeiro, não há histórico a preservar por trás dele
  async remove(usuarioId: string, id: string) {
    await this.findOne(usuarioId, id);
    await this.prisma.ganho.delete({ where: { id_ganho: id } });
    return { mensagem: 'Ganho removido com sucesso' };
  }

  // HU17: duplicar cria um novo registro, então veículo e plataforma precisam estar ativos
  async duplicar(usuarioId: string, id: string, dto: DuplicarGanhoDto) {
    const ganhoOriginal = await this.findOne(usuarioId, id);

    await Promise.all([
      this.validarVeiculo(usuarioId, ganhoOriginal.id_veiculo),
      this.validarPlataforma(usuarioId, ganhoOriginal.id_plataforma),
    ]);

    return this.prisma.ganho.create({
      data: {
        id_veiculo: ganhoOriginal.id_veiculo,
        id_plataforma: ganhoOriginal.id_plataforma,
        valor: ganhoOriginal.valor,
        data: dto.data ? new Date(dto.data) : ganhoOriginal.data,
      },
    });
  }
}