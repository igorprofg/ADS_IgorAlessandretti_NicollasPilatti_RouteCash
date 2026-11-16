import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';

// Barra quem não é administrador. Deve vir DEPOIS do JwtAuthGuard,
// que é quem preenche request.user:
//   @UseGuards(JwtAuthGuard, AdministradorGuard)
@Injectable()
export class AdministradorGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context
      .switchToHttp()
      .getRequest<{ user?: { tipo_usuario?: string } }>();

    if (request.user?.tipo_usuario !== 'ADMINISTRADOR') {
      throw new ForbiddenException('Acesso restrito a administradores');
    }
    return true;
  }
}