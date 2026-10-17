import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RegistrarQuilometragemDto } from './dto/registrar-quilometragem.dto';
import { AtualizarQuilometragemDto } from './dto/atualizar-quilometragem.dto';

type JornadaComVeiculo = Prisma.JornadaGetPayload<{ include: { veiculo: true } }>;

// No modelo lógico, a quilometragem é o campo km_rodados da JORNADA.
// Por isso o registro já nasce vinculado a um veículo e a uma data (os da jornada).
@Injectable()
export class QuilometragemService {
  constructor(private readonly prisma: PrismaService) {}

  private formatar(j: JornadaComVeiculo) {
    return {
      id_jornada: j.id_jornada,
      km_rodados: Number(j.km_rodados),
      data: j.inicio,
      veiculo: {
        id_veiculo: j.veiculo.id_veiculo,
        marca: j.veiculo.marca,
        modelo: j.veiculo.modelo,
        placa: j.veiculo.placa,
      },
    };
  }

  // Posse: a jornada precisa pertencer ao usuário autenticado
  private async buscarJornada(usuarioId: string, id_jornada: string) {
    const jornada = await this.prisma.jornada.findFirst({
      where: { id_jornada, id_usuario: usuarioId },
    });
    if (!jornada) {
      throw new NotFoundException('Jornada não encontrada');
    }
    return jornada;
  }

  // Usado por editar e remover: exige que já exista quilometragem registrada
  private async buscarComQuilometragem(usuarioId: string, id_jornada: string) {
    const jornada = await this.buscarJornada(usuarioId, id_jornada);
    if (jornada.km_rodados === null) {
      throw new NotFoundException(
        'Esta jornada não possui quilometragem registrada',
      );
    }
    return jornada;
  }

  // HU25: registrar quilometragem (km > 0 validado no DTO)
  async registrar(usuarioId: string, dto: RegistrarQuilometragemDto) {
    const jornada = await this.buscarJornada(usuarioId, dto.id_jornada);
    if (jornada.km_rodados !== null) {
      throw new ConflictException(
        'Esta jornada já possui quilometragem registrada. Use a edição',
      );
    }

    const atualizada = await this.prisma.jornada.update({
      where: { id_jornada: dto.id_jornada },
      data: { km_rodados: dto.km_rodados },
      include: { veiculo: true },
    });
    return this.formatar(atualizada);
  }

  async findAll(usuarioId: string) {
    const jornadas = await this.prisma.jornada.findMany({
      where: { id_usuario: usuarioId, km_rodados: { not: null } },
      include: { veiculo: true },
      orderBy: { inicio: 'desc' },
    });
    return jornadas.map((j) => this.formatar(j));
  }

  // HU26: editar quilometragem
  async atualizar(
    usuarioId: string,
    id_jornada: string,
    dto: AtualizarQuilometragemDto,
  ) {
    await this.buscarComQuilometragem(usuarioId, id_jornada);

    const atualizada = await this.prisma.jornada.update({
      where: { id_jornada },
      data: { km_rodados: dto.km_rodados },
      include: { veiculo: true },
    });
    return this.formatar(atualizada);
  }

  // HU27: remover o registro = limpar o km da jornada (a jornada em si é preservada)
  async remover(usuarioId: string, id_jornada: string) {
    await this.buscarComQuilometragem(usuarioId, id_jornada);

    await this.prisma.jornada.update({
      where: { id_jornada },
      data: { km_rodados: null },
    });
    return { mensagem: 'Quilometragem removida com sucesso' };
  }
}