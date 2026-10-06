import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CriarVeiculoDto } from './dto/criar-veiculo.dto';
import { AtualizarVeiculoDto } from './dto/atualizar-veiculo.dto';

@Injectable()
export class VeiculosService {
  constructor(private readonly prisma: PrismaService) {}

  // RN16/RN18: motorista pode ter vários veículos; marca/modelo/ano/combustível obrigatórios (DTO já valida)
  async create(usuarioId: string, dto: CriarVeiculoDto) {
    try {
      return await this.prisma.veiculo.create({
        data: { ...dto, id_usuario: usuarioId },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('Já existe um veículo cadastrado com essa placa');
      }
      throw error;
    }
  }

  async findAll(usuarioId: string) {
    return this.prisma.veiculo.findMany({
      where: { id_usuario: usuarioId, ativo: true },
      orderBy: { data_cadastro: 'asc' },
    });
  }

  // RN17/RN19: só retorna/opera em veículo que pertence ao usuário autenticado
  async findOne(usuarioId: string, id: string) {
    const veiculo = await this.prisma.veiculo.findFirst({
      where: { id_veiculo: id, id_usuario: usuarioId },
    });
    if (!veiculo) {
      throw new NotFoundException('Veículo não encontrado');
    }
    return veiculo;
  }

  async update(usuarioId: string, id: string, dto: AtualizarVeiculoDto) {
    await this.findOne(usuarioId, id);
    return this.prisma.veiculo.update({
      where: { id_veiculo: id },
      data: dto,
    });
  }

  // RN21: soft delete - preserva ganhos/despesas/jornadas históricos vinculados ao veículo
  async remove(usuarioId: string, id: string) {
    await this.findOne(usuarioId, id);
    await this.prisma.veiculo.update({
      where: { id_veiculo: id },
      data: { ativo: false, principal: false },
    });
    return { mensagem: 'Veículo removido com sucesso' };
  }

  // RN23/RN24: apenas um veículo principal por vez; definir um novo tira o status do anterior
  async definirPrincipal(usuarioId: string, id: string) {
    await this.findOne(usuarioId, id);

    await this.prisma.$transaction([
      this.prisma.veiculo.updateMany({
        where: { id_usuario: usuarioId, principal: true },
        data: { principal: false },
      }),
      this.prisma.veiculo.update({
        where: { id_veiculo: id },
        data: { principal: true },
      }),
    ]);

    return { mensagem: 'Veículo definido como principal' };
  }
}