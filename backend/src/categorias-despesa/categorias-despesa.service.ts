import {
  BadRequestException,
  ConflictException,
  Injectable,
  OnModuleInit,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CriarCategoriaDespesaDto } from './dto/criar-categoria-despesa.dto';

// HU21: categorias padrão do sistema (id_usuario nulo), compartilhadas por todos os usuários
const CATEGORIAS_PADRAO = [
  'Combustível',
  'Manutenção',
  'Alimentação',
  'Seguro',
  'Pedágio',
  'Outros',
];

@Injectable()
export class CategoriasDespesaService implements OnModuleInit {
  constructor(private readonly prisma: PrismaService) {}

  // Garante que as categorias padrão existam (idempotente: roda a cada boot, só cria o que falta)
  async onModuleInit() {
    for (const nome of CATEGORIAS_PADRAO) {
      const existe = await this.prisma.categoriaDespesa.findFirst({
        where: { nome, id_usuario: null },
      });
      if (!existe) {
        await this.prisma.categoriaDespesa.create({
          data: { nome, id_usuario: null },
        });
      }
    }
  }

  // Lista as categorias padrão + as personalizadas do usuário
  async findAll(usuarioId: string) {
    return this.prisma.categoriaDespesa.findMany({
      where: { OR: [{ id_usuario: null }, { id_usuario: usuarioId }] },
      orderBy: { nome: 'asc' },
    });
  }

  // HU21 / RN: não pode haver categoria duplicada pro mesmo usuário
  // (a checagem considera também as categorias padrão e ignora maiúsculas/minúsculas)
  async create(usuarioId: string, dto: CriarCategoriaDespesaDto) {
    const nome = dto.nome.trim();
    if (!nome) {
      throw new BadRequestException('O nome da categoria é obrigatório');
    }

    const duplicada = await this.prisma.categoriaDespesa.findFirst({
      where: {
        nome: { equals: nome, mode: 'insensitive' },
        OR: [{ id_usuario: null }, { id_usuario: usuarioId }],
      },
    });
    if (duplicada) {
      throw new ConflictException('Já existe uma categoria com esse nome');
    }

    try {
      return await this.prisma.categoriaDespesa.create({
        data: { nome, id_usuario: usuarioId },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('Já existe uma categoria com esse nome');
      }
      throw error;
    }
  }
}