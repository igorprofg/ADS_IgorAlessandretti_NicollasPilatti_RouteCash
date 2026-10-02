import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET,
    });
  }

  // O que for retornado aqui vira "request.user" em toda rota protegida
  async validate(payload: { sub: string; tipo: string }) {
    return { id_usuario: payload.sub, tipo_usuario: payload.tipo };
  }
}