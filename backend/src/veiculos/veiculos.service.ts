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

  // A placa é única POR USUÁRIO.
  //
  // Usuários diferentes podem cadastrar a mesma placa.
  //
  // Se o próprio usuário já possuir um veículo INATIVO
  // com essa placa, retornamos o ID para o app poder
  // oferecer a opção de reativação.
  private async validarPlacaLivre(
    usuarioId: string,
    placa?: string,
    ignorarId?: string,
  ) {
    const placaNormalizada = placa?.trim();

    if (!placaNormalizada) {
      return;
    }

    const existente = await this.prisma.veiculo.findFirst({
      where: {
        id_usuario: usuarioId,
        placa: placaNormalizada,

        ...(ignorarId
          ? {
              id_veiculo: {
                not: ignorarId,
              },
            }
          : {}),
      },
    });

    if (!existente) {
      return;
    }

    // O usuário já possui esse veículo,
    // porém ele está removido/inativo.
    if (!existente.ativo) {
      throw new ConflictException({
        statusCode: 409,
        error: 'Conflict',
        message:
          'Você já tem um veículo removido com essa placa. Reative-o na lista de inativos',
        id_veiculo_inativo: existente.id_veiculo,
      });
    }

    // Existe outro veículo ativo com a mesma placa
    // dentro da própria conta.
    throw new ConflictException(
      'Você já possui um veículo cadastrado com essa placa',
    );
  }

  // Segurança adicional para situações em que duas
  // requisições tentem cadastrar a mesma placa ao mesmo tempo.
  //
  // A proteção definitiva também ficará no PostgreSQL
  // através do índice único por usuário + placa.
  private erroPlaca(error: unknown) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    ) {
      return new ConflictException(
        'Você já possui um veículo cadastrado com essa placa',
      );
    }

    return error;
  }

  // RN16/RN18:
  // motorista pode possuir vários veículos.
  //
  // Marca, modelo, ano e combustível são validados pelo DTO.
  async create(usuarioId: string, dto: CriarVeiculoDto) {
    const placaNormalizada = dto.placa?.trim() || undefined;

    await this.validarPlacaLivre(
      usuarioId,
      placaNormalizada,
    );

    try {
      return await this.prisma.veiculo.create({
        data: {
          ...dto,
          placa: placaNormalizada,
          id_usuario: usuarioId,
        },
      });
    } catch (error) {
      throw this.erroPlaca(error);
    }
  }

  // Lista somente os veículos ativos do usuário.
  async findAll(usuarioId: string) {
    return this.prisma.veiculo.findMany({
      where: {
        id_usuario: usuarioId,
        ativo: true,
      },
      orderBy: {
        data_cadastro: 'asc',
      },
    });
  }

  // Lista veículos removidos/inativos.
  //
  // Utilizado pela aba "Veículos inativos"
  // para permitir futura reativação.
  async findInativos(usuarioId: string) {
    return this.prisma.veiculo.findMany({
      where: {
        id_usuario: usuarioId,
        ativo: false,
      },
      orderBy: {
        data_atualizacao: 'desc',
      },
    });
  }

  // RN17/RN19:
  // somente retorna veículos pertencentes
  // ao usuário autenticado.
  //
  // Pode encontrar tanto ativos quanto inativos.
  async findOne(
    usuarioId: string,
    id: string,
  ) {
    const veiculo =
      await this.prisma.veiculo.findFirst({
        where: {
          id_veiculo: id,
          id_usuario: usuarioId,
        },
      });

    if (!veiculo) {
      throw new NotFoundException(
        'Veículo não encontrado',
      );
    }

    return veiculo;
  }

  // Veículos removidos não podem ser alterados
  // diretamente nem definidos como principal.
  //
  // Primeiro devem ser reativados.
  private async buscarAtivo(
    usuarioId: string,
    id: string,
  ) {
    const veiculo =
      await this.findOne(
        usuarioId,
        id,
      );

    if (!veiculo.ativo) {
      throw new BadRequestException(
        'Este veículo está removido. Reative-o antes de alterá-lo',
      );
    }

    return veiculo;
  }

  async update(
    usuarioId: string,
    id: string,
    dto: AtualizarVeiculoDto,
  ) {
    await this.buscarAtivo(
      usuarioId,
      id,
    );

    const placaNormalizada =
      dto.placa?.trim() || undefined;

    // Só valida a placa se ela estiver sendo enviada
    // na atualização.
    if (dto.placa !== undefined) {
      await this.validarPlacaLivre(
        usuarioId,
        placaNormalizada,
        id,
      );
    }

    try {
      return await this.prisma.veiculo.update({
        where: {
          id_veiculo: id,
        },
        data: {
          ...dto,

          ...(dto.placa !== undefined
            ? {
                placa: placaNormalizada,
              }
            : {}),
        },
      });
    } catch (error) {
      throw this.erroPlaca(error);
    }
  }

  // RN21:
  // soft delete.
  //
  // O veículo permanece no banco para preservar
  // ganhos, despesas e jornadas históricas.
  async remove(
    usuarioId: string,
    id: string,
  ) {
    await this.findOne(
      usuarioId,
      id,
    );

    await this.prisma.veiculo.update({
      where: {
        id_veiculo: id,
      },
      data: {
        ativo: false,
        principal: false,
      },
    });

    return {
      mensagem:
        'Veículo removido com sucesso',
    };
  }

  // Reativa um veículo anteriormente removido.
  //
  // Ele volta como não principal, pois o status
  // principal foi removido durante o soft delete.
  async reativar(
    usuarioId: string,
    id: string,
  ) {
    const veiculo =
      await this.findOne(
        usuarioId,
        id,
      );

    if (veiculo.ativo) {
      throw new BadRequestException(
        'Este veículo já está ativo',
      );
    }

    return this.prisma.veiculo.update({
      where: {
        id_veiculo: id,
      },
      data: {
        ativo: true,
      },
    });
  }

  // RN23/RN24:
  // apenas um veículo pode ser principal
  // para cada usuário.
  //
  // Ao definir um novo principal, o anterior
  // perde automaticamente esse status.
  async definirPrincipal(
    usuarioId: string,
    id: string,
  ) {
    await this.buscarAtivo(
      usuarioId,
      id,
    );

    await this.prisma.$transaction([
      this.prisma.veiculo.updateMany({
        where: {
          id_usuario: usuarioId,
          principal: true,
        },
        data: {
          principal: false,
        },
      }),

      this.prisma.veiculo.update({
        where: {
          id_veiculo: id,
        },
        data: {
          principal: true,
        },
      }),
    ]);

    return {
      mensagem:
        'Veículo definido como principal',
    };
  }
}