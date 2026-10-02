import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { CriarUsuarioDto } from './dto/criar-usuario.dto';
import { AtualizarUsuarioDto } from './dto/atualizar-usuario.dto';

const PLATAFORMAS_PADRAO = ['Uber', '99', 'inDrive'];

@Injectable()
export class UsuariosService {
  constructor(private readonly prisma: PrismaService) {}

  async create(dto: CriarUsuarioDto) {
    if (dto.senha !== dto.confirmarSenha) {
      throw new BadRequestException('As senhas não coincidem');
    }
    if (!dto.aceiteTermos) {
      throw new BadRequestException('É necessário aceitar os Termos de Uso');
    }

    const emailExistente = await this.prisma.usuario.findUnique({
      where: { email: dto.email },
    });
    if (emailExistente) {
      throw new ConflictException('Este e-mail já está cadastrado');
    }

    const senha_hash = await bcrypt.hash(dto.senha, 10);

    const usuario = await this.prisma.usuario.create({
      data: {
        nome: dto.nome,
        email: dto.email,
        senha_hash,
        tipo_usuario: 'MOTORISTA',
        aceite_termos_em: new Date(),
      },
    });

    // RF04/HU10: plataformas padrão são criadas automaticamente pra cada novo usuário
    await this.prisma.plataforma.createMany({
      data: PLATAFORMAS_PADRAO.map((nome) => ({
        nome,
        id_usuario: usuario.id_usuario,
        padrao: true,
      })),
    });

    return this.semSenha(usuario);
  }

  async findOne(id: string) {
    const usuario = await this.prisma.usuario.findUnique({
      where: { id_usuario: id },
    });
    if (!usuario) {
      throw new NotFoundException('Usuário não encontrado');
    }
    return this.semSenha(usuario);
  }

  async update(id: string, dto: AtualizarUsuarioDto) {
    await this.findOne(id);
    const usuario = await this.prisma.usuario.update({
      where: { id_usuario: id },
      data: dto,
    });
    return this.semSenha(usuario);
  }

  // RF01/HU05: exclusão de conta - bloqueia acesso, não apaga fisicamente
  // (usuário tem relações com veículos/ganhos/despesas que precisam ser preservados)
  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.usuario.update({
      where: { id_usuario: id },
      data: { status_conta: 'BLOQUEADO' },
    });
    return { mensagem: 'Conta encerrada com sucesso' };
  }

  private semSenha(usuario: { senha_hash: string; [key: string]: unknown }) {
    const { senha_hash, ...resto } = usuario;
    return resto;
  }
}