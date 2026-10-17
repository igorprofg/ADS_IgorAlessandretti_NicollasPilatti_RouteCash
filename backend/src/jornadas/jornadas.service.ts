import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { IniciarJornadaDto } from './dto/iniciar-jornada.dto';
import { FinalizarJornadaDto } from './dto/finalizar-jornada.dto';
import { AtualizarJornadaDto } from './dto/atualizar-jornada.dto';

// Tolerância para diferença de relógio entre o celular e o servidor
const TOLERANCIA_MS = 5 * 60 * 1000;

@Injectable()
export class JornadasService {
  constructor(private readonly prisma: PrismaService) {}

  private validarNaoFuturo(data: Date, campo: string) {
    if (data.getTime() > Date.now() + TOLERANCIA_MS) {
      throw new BadRequestException(`${campo} não pode estar no futuro`);
    }
  }

  // HU23/HU24: o horário final precisa resultar em uma duração válida
  private validarPeriodo(inicio: Date, fim: Date | null) {
    if (fim && fim.getTime() <= inicio.getTime()) {
      throw new BadRequestException(
        'O horário final deve ser posterior ao horário de início',
      );
    }
  }

  // HU23: a duração não é guardada no banco, é calculada a partir de início e fim
  private comDuracao<T extends { inicio: Date; fim: Date | null }>(jornada: T) {
    const duracao_minutos = jornada.fim
      ? Math.round((jornada.fim.getTime() - jornada.inicio.getTime()) / 60000)
      : null;
    return { ...jornada, duracao_minutos };
  }

  // Posse: a jornada precisa pertencer ao usuário autenticado
  private async buscar(usuarioId: string, id: string) {
    const jornada = await this.prisma.jornada.findFirst({
      where: { id_jornada: id, id_usuario: usuarioId },
      include: { veiculo: true },
    });
    if (!jornada) {
      throw new NotFoundException('Jornada não encontrada');
    }
    return jornada;
  }

  // HU22: iniciar jornada
  async iniciar(usuarioId: string, dto: IniciarJornadaDto) {
    const veiculo = await this.prisma.veiculo.findFirst({
      where: { id_veiculo: dto.id_veiculo, id_usuario: usuarioId, ativo: true },
    });
    if (!veiculo) {
      throw new NotFoundException('Veículo não encontrado ou removido');
    }

    // RN: não pode existir mais de uma jornada em aberto ao mesmo tempo
    const emAberto = await this.prisma.jornada.findFirst({
      where: { id_usuario: usuarioId, fim: null },
    });
    if (emAberto) {
      throw new ConflictException(
        'Já existe uma jornada em andamento. Finalize-a antes de iniciar outra',
      );
    }

    const inicio = dto.inicio ? new Date(dto.inicio) : new Date();
    this.validarNaoFuturo(inicio, 'O horário de início');

    const jornada = await this.prisma.jornada.create({
      data: { id_usuario: usuarioId, id_veiculo: dto.id_veiculo, inicio },
    });
    return this.comDuracao(jornada);
  }

  async findAll(usuarioId: string) {
    const jornadas = await this.prisma.jornada.findMany({
      where: { id_usuario: usuarioId },
      include: { veiculo: true },
      orderBy: { inicio: 'desc' },
    });
    return jornadas.map((j) => this.comDuracao(j));
  }

  // Útil para o mobile saber se há uma jornada aberta (e mostrar o botão "finalizar")
  async findEmAndamento(usuarioId: string) {
    const jornada = await this.prisma.jornada.findFirst({
      where: { id_usuario: usuarioId, fim: null },
      include: { veiculo: true },
    });
    if (!jornada) {
      throw new NotFoundException('Nenhuma jornada em andamento');
    }
    return this.comDuracao(jornada);
  }

  async findOne(usuarioId: string, id: string) {
    return this.comDuracao(await this.buscar(usuarioId, id));
  }

  // HU23: finalizar jornada
  async finalizar(usuarioId: string, id: string, dto: FinalizarJornadaDto) {
    const atual = await this.buscar(usuarioId, id);

    // RN: só dá para finalizar uma jornada que está em andamento
    if (atual.fim) {
      throw new BadRequestException('Esta jornada já foi finalizada');
    }

    const fim = dto.fim ? new Date(dto.fim) : new Date();
    this.validarNaoFuturo(fim, 'O horário final');
    this.validarPeriodo(atual.inicio, fim);

    const jornada = await this.prisma.jornada.update({
      where: { id_jornada: id },
      data: { fim },
    });
    return this.comDuracao(jornada);
  }

  // HU24: corrigir os horários de uma jornada
  async update(usuarioId: string, id: string, dto: AtualizarJornadaDto) {
    const atual = await this.buscar(usuarioId, id);

    const novoInicio = dto.inicio ? new Date(dto.inicio) : undefined;
    const novoFim = dto.fim ? new Date(dto.fim) : undefined;

    if (novoInicio) this.validarNaoFuturo(novoInicio, 'O horário de início');
    if (novoFim) this.validarNaoFuturo(novoFim, 'O horário final');
    this.validarPeriodo(novoInicio ?? atual.inicio, novoFim ?? atual.fim);

    const jornada = await this.prisma.jornada.update({
      where: { id_jornada: id },
      data: {
        ...(novoInicio && { inicio: novoInicio }),
        ...(novoFim && { fim: novoFim }),
      },
    });
    return this.comDuracao(jornada);
  }
}