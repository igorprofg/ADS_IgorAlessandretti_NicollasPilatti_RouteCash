import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CriarPlataformaDto } from './dto/criar-plataforma.dto';
import { AtualizarPlataformaDto } from './dto/atualizar-plataforma.dto';

@Injectable()
export class PlataformasService {
  constructor(private readonly prisma: PrismaService) {}

  // HU10: lista as plataformas do usuário (padrão + personalizadas) pra ele escolher nos lançamentos de ganho
  async findAll(usuarioId: string) {
    return this.prisma.plataforma.findMany({
      where: { id_usuario: usuarioId },
      orderBy: [{ padrao: 'desc' }, { nome: 'asc' }],
    });
  }

  async findOne(usuarioId: string, id: string) {
    const plataforma = await this.prisma.plataforma.findFirst({
      where: { id_plataforma: id, id_usuario: usuarioId },
    });
    if (!plataforma) {
      throw new NotFoundException('Plataforma não encontrada');
    }
    return plataforma;
  }

  // HU11 / RN25: impede plataforma duplicada pro mesmo usuário
  async create(usuarioId: string, dto: CriarPlataformaDto) {
    try {
      return await this.prisma.plataforma.create({
        data: { nome: dto.nome, id_usuario: usuarioId, padrao: false },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('Você já tem uma plataforma com esse nome');
      }
      throw error;
    }
  }

  // HU12: plataformas padrão do sistema não podem ter o nome alterado
  async update(usuarioId: string, id: string, dto: AtualizarPlataformaDto) {
    const plataforma = await this.findOne(usuarioId, id);
    if (plataforma.padrao) {
      throw new ForbiddenException(
        'Plataformas padrão do sistema não podem ser editadas',
      );
    }

    try {
      return await this.prisma.plataforma.update({
        where: { id_plataforma: id },
        data: { nome: dto.nome },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('Você já tem uma plataforma com esse nome');
      }
      throw error;
    }
  }

  // HU13 / RN26: ativar/inativar - permitido tanto pra plataforma padrão quanto personalizada
  // (inativa = não aparece em novos registros de ganho, mas preserva o histórico já lançado)
  async alternarAtiva(usuarioId: string, id: string) {
    const plataforma = await this.findOne(usuarioId, id);
    return this.prisma.plataforma.update({
      where: { id_plataforma: id },
      data: { ativa: !plataforma.ativa }, 
    });
  }
}