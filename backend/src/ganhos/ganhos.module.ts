
import { Module } from '@nestjs/common';

import { GanhosController } from './ganhos.controller';
import { GanhosService } from './ganhos.service';

// Disponibiliza o PrismaService para consultar assinaturas.
import { PrismaModule } from '../prisma/prisma.module';

// Guard responsável por validar a assinatura.
import { AssinaturaAtivaGuard } from '../common/guards/assinatura-ativa.guard';

@Module({
  imports: [
    PrismaModule,
  ],

  controllers: [
    GanhosController,
  ],

  providers: [
    GanhosService,
    AssinaturaAtivaGuard,
  ],
})
export class GanhosModule {}
