import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { SalvarDadosPagamentoDto } from './dto/salvar-dados-pagamento.dto';
import { documentoValido } from './validar-documento';

const CAMPOS = {
  cpf_cnpj: true,
  celular: true,
  cep: true,
  logradouro: true,
  numero_endereco: true,
  complemento: true,
  bairro: true,
} as const;

interface DadosBrutos {
  cpf_cnpj: string | null;
  celular: string | null;
  cep: string | null;
  logradouro: string | null;
  numero_endereco: string | null;
  complemento: string | null;
  bairro: string | null;
}

// Dados que o Asaas exige para cobrar o motorista. São do PRÓPRIO usuário logado.
// O AsaasService já reaproveita e atualiza o cliente no Asaas a cada contratação.
@Injectable()
export class DadosPagamentoService {
  constructor(private readonly prisma: PrismaService) {}

  private serializar(u: DadosBrutos) {
    return {
      ...u,
      // true quando já dá para iniciar um checkout (mesmos campos que o AsaasService exige)
      completo: Boolean(u.cpf_cnpj && u.cep && u.logradouro && u.numero_endereco && u.bairro),
    };
  }

  async obter(usuarioId: string) {
    const usuario = await this.prisma.usuario.findUnique({
      where: { id_usuario: usuarioId },
      select: CAMPOS,
    });
    if (!usuario) {
      throw new NotFoundException('Usuário não encontrado');
    }
    return this.serializar(usuario);
  }

  async salvar(usuarioId: string, dto: SalvarDadosPagamentoDto) {
    if (!documentoValido(dto.cpf_cnpj)) {
      throw new BadRequestException('CPF/CNPJ inválido');
    }

    try {
      const atualizado = await this.prisma.usuario.update({
        where: { id_usuario: usuarioId },
        data: {
          cpf_cnpj: dto.cpf_cnpj,
          celular: dto.celular ?? null,
          cep: dto.cep,
          logradouro: dto.logradouro,
          numero_endereco: dto.numero_endereco,
          complemento: dto.complemento ?? null,
          bairro: dto.bairro,
        },
        select: CAMPOS,
      });
      return this.serializar(atualizado);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Este CPF/CNPJ já está cadastrado em outra conta');
      }
      throw error;
    }
  }
}