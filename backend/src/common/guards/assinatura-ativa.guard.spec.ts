
import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { AssinaturaAtivaGuard } from './assinatura-ativa.guard';
import { PrismaService } from '../../prisma/prisma.service';

describe('AssinaturaAtivaGuard', () => {
  const findFirst = jest.fn();

  let guard: AssinaturaAtivaGuard;

  const contexto = {
    switchToHttp: () => ({
      getRequest: () => ({
        user: {
          id_usuario: 'usuario-teste',
          tipo_usuario: 'MOTORISTA',
        },
      }),
    }),
  } as ExecutionContext;

  beforeEach(() => {
    jest.clearAllMocks();

    const prisma = {
      assinatura: {
        findFirst,
      },
    } as unknown as PrismaService;

    guard = new AssinaturaAtivaGuard(prisma);
  });

  it('bloqueia assinatura suspensa', async () => {
    // O Prisma não encontra assinatura ATIVA,
    // pois o usuário possui apenas uma SUSPENSA.
    findFirst.mockResolvedValue(null);

    await expect(
      guard.canActivate(contexto),
    ).rejects.toThrow(ForbiddenException);

    expect(findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          situacao: 'ATIVA',
        }),
      }),
    );
  });

  it('bloqueia assinatura vencida', async () => {
    // A assinatura está ATIVA no banco,
    // mas fora do período permitido.
    // A consulta filtrada não retorna registros.
    findFirst.mockResolvedValue(null);

    await expect(
      guard.canActivate(contexto),
    ).rejects.toThrow(ForbiddenException);

    expect(findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          data_vencimento: {
            gte: expect.any(Date),
          },
        }),
      }),
    );
  });

  it('libera assinatura ativa e válida', async () => {
    findFirst.mockResolvedValue({
      id_assinatura: 'assinatura-teste',
    });

    await expect(
      guard.canActivate(contexto),
    ).resolves.toBe(true);
  });
});
