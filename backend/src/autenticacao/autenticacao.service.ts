import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AutenticacaoService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async login(dto: LoginDto) {
    const usuario = await this.prisma.usuario.findUnique({
      where: { email: dto.email },
    });

    // RN01/RN02: e-mail e senha obrigatórios, credenciais devem corresponder a um usuário cadastrado
    if (!usuario) {
      throw new UnauthorizedException('E-mail ou senha inválidos');
    }

    const senhaValida = await bcrypt.compare(dto.senha, usuario.senha_hash);
    if (!senhaValida) {
      throw new UnauthorizedException('E-mail ou senha inválidos');
    }

    // RN03: somente usuários com acesso válido poderão entrar no sistema
    if (usuario.status_conta !== 'ATIVO') {
      throw new UnauthorizedException('Conta inativa ou bloqueada');
    }

    const payload = { sub: usuario.id_usuario, tipo: usuario.tipo_usuario };
    const access_token = await this.jwtService.signAsync(payload);

    return {
      access_token,
      usuario: {
        id_usuario: usuario.id_usuario,
        nome: usuario.nome,
        email: usuario.email,
        tipo_usuario: usuario.tipo_usuario,
      },
    };
  }
}