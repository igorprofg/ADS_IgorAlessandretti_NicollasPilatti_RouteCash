import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const UsuarioAtual = createParamDecorator(
  (data: unknown, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    return request.user?.id_usuario;
  },
);