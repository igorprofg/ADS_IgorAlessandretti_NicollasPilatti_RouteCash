import { Module } from '@nestjs/common';

import { PrismaModule } from '../prisma/prisma.module';
import { AsaasModule } from '../asaas/asaas.module';

import { AssinaturasController } from './assinaturas.controller';
import { AssinaturasService } from './assinaturas.service';

@Module({
  imports: [
    // Disponibiliza o PrismaService
    PrismaModule,

    // Disponibiliza o AsaasService
    AsaasModule,
  ],

  controllers: [
    AssinaturasController,
  ],

  providers: [
    AssinaturasService,
  ],

  // O módulo de planos utiliza o AssinaturasService
  // para identificar o plano contratado pelo usuário.
  exports: [
    AssinaturasService,
  ],
})
export class AssinaturasModule {}