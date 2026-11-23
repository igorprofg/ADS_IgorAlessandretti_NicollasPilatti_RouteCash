
import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { hojeComoData } from '../periodo-cobranca';

@Injectable()
export class AssinaturaAtivaGuard implements CanActivate {
  constructor(
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(
    context: ExecutionContext,
  ): Promise<boolean> {
    const request = context.switchToHttp().getRequest();

    // O JwtAuthGuard deve executar antes deste Guard.
    // A JwtStrategy coloca o usuário autenticado
    // dentro de request.user.
    const usuarioId = request.user?.id_usuario;

    if (!usuarioId) {
      throw new UnauthorizedException(
        'Usuário não autenticado.',
      );
    }

    // Utilizamos a mesma função de datas do
    // AssinaturasService para manter consistência.
    const hoje = hojeComoData();

    // Uma assinatura somente libera o acesso quando:
    //
    // 1. Pertence ao usuário autenticado;
    // 2. Está com situação ATIVA;
    // 3. Já iniciou sua vigência;
    // 4. Ainda não chegou ao fim da validade.
    //
    // A data de vencimento é inclusiva:
    // o motorista poderá utilizar o sistema
    // durante todo o dia do vencimento.

    const assinatura = await this.prisma.assinatura.findFirst({
      where: {
        id_usuario: usuarioId,
        situacao: 'ATIVA',
        data_inicio: {
          lte: hoje,
        },
        data_vencimento: {
          gte: hoje,
        },
      },
      select: {
        id_assinatura: true,
      },
    });

    if (!assinatura) {
      throw new ForbiddenException({
        codigo: 'ASSINATURA_NECESSARIA',
        mensagem:
          'Você precisa de uma assinatura ativa e válida para acessar esta funcionalidade.',
      });
    }

    return true;
  }
}
