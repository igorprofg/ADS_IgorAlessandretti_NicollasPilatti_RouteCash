import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET,
    });
  }

  // Roda em toda rota protegida. Confere no banco se a conta ainda está ativa e qual é o tipo
  // atual do usuário, assim suspender ou bloquear um assinante (RF15) vale NA HORA,
  // sem esperar o token expirar. O que for retornado aqui vira "request.user".
  async validate(payload: { sub: string }) {
    const usuario = await this.prisma.usuario.findUnique({
      where: { id_usuario: payload.sub },
      select: { id_usuario: true, tipo_usuario: true, status_conta: true },
    });

    if (!usuario || usuario.status_conta !== 'ATIVO') {
      throw new UnauthorizedException('Conta inativa ou bloqueada');
    }

    return { id_usuario: usuario.id_usuario, tipo_usuario: usuario.tipo_usuario };
  }
}