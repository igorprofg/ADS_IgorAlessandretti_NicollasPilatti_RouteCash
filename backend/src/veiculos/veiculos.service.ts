import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CriarVeiculoDto } from './dto/criar-veiculo.dto';
import { AtualizarVeiculoDto } from './dto/atualizar-veiculo.dto';

@Injectable()
export class VeiculosService {
  constructor(private readonly prisma: PrismaService) {}

  // A placa é única no sistema. Se o conflito for com um veículo REMOVIDO do próprio usuário,
  // a resposta traz o id dele para o app oferecer "reativar" em vez de cadastrar de novo
  private async validarPlacaLivre(
    usuarioId: string,
    placa?: string,
    ignorarId?: string,
  ) {
    if (!placa) return;

    const existente = await this.prisma.veiculo.findUnique({ where: { placa } });
    if (!existente || existente.id_veiculo === ignorarId) return;

    if (existente.id_usuario === usuarioId && !existente.ativo) {
      throw new ConflictException({
        statusCode: 409,
        error: 'Conflict',
        message:
          'Você já tem um veículo removido com essa placa. Reative-o na lista de inativos',
        id_veiculo_inativo: existente.id_veiculo,
      });
    }
    throw new ConflictException('Já existe um veículo cadastrado com essa placa');
  }

  // Segurança extra contra disputa entre duas requisições simultâneas (violação de UNIQUE)
  private erroPlaca(error: unknown) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    ) {
      return new ConflictException('Já existe um veículo cadastrado com essa placa');
    }
    return error;
  }

  // RN16/RN18: motorista pode ter vários veículos; marca/modelo/ano/combustível obrigatórios (DTO valida)
  async create(usuarioId: string, dto: CriarVeiculoDto) {
    await this.validarPlacaLivre(usuarioId, dto.placa);

    try {
      return await this.prisma.veiculo.create({
        data: { ...dto, id_usuario: usuarioId },
      });
    } catch (error) {
      throw this.erroPlaca(error);
    }
  }

  // Lista só os veículos ativos
  async findAll(usuarioId: string) {
    return this.prisma.veiculo.findMany({
      where: { id_usuario: usuarioId, ativo: true },
      orderBy: { data_cadastro: 'asc' },
    });
  }

  // Lista os veículos removidos (soft delete), para a aba "Veículos inativos" do app
  async findInativos(usuarioId: string) {
    return this.prisma.veiculo.findMany({
      where: { id_usuario: usuarioId, ativo: false },
      orderBy: { data_atualizacao: 'desc' },
    });
  }

  // RN17/RN19: só retorna/opera em veículo que pertence ao usuário autenticado (ativo ou não)
  async findOne(usuarioId: string, id: string) {
    const veiculo = await this.prisma.veiculo.findFirst({
      where: { id_veiculo: id, id_usuario: usuarioId },
    });
    if (!veiculo) {
      throw new NotFoundException('Veículo não encontrado');
    }
    return veiculo;
  }

  // Veículo removido não pode ser alterado nem virar principal: precisa ser reativado antes
  private async buscarAtivo(usuarioId: string, id: string) {
    const veiculo = await this.findOne(usuarioId, id);
    if (!veiculo.ativo) {
      throw new BadRequestException(
        'Este veículo está removido. Reative-o antes de alterá-lo',
      );
    }
    return veiculo;
  }

  async update(usuarioId: string, id: string, dto: AtualizarVeiculoDto) {
    await this.buscarAtivo(usuarioId, id);
    await this.validarPlacaLivre(usuarioId, dto.placa, id);

    try {
      return await this.prisma.veiculo.update({
        where: { id_veiculo: id },
        data: dto,
      });
    } catch (error) {
      throw this.erroPlaca(error);
    }
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

  // Reativa um veículo removido. Ele volta como não-principal (o status foi limpo na remoção)
  async reativar(usuarioId: string, id: string) {
    const veiculo = await this.findOne(usuarioId, id);
    if (veiculo.ativo) {
      throw new BadRequestException('Este veículo já está ativo');
    }
    return this.prisma.veiculo.update({
      where: { id_veiculo: id },
      data: { ativo: true },
    });
  }

  // RN23/RN24: apenas um veículo principal por vez; definir um novo tira o status do anterior
  async definirPrincipal(usuarioId: string, id: string) {
    await this.buscarAtivo(usuarioId, id);

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