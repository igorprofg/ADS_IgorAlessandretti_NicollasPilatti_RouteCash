import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { PrismaModule } from '../prisma/prisma.module';

import { AsaasController } from './asaas.controller';
import { AsaasService } from './asaas.service';

@Module({
  imports: [
    ConfigModule,
    PrismaModule,
  ],
  controllers: [AsaasController],
  providers: [AsaasService],
  exports: [AsaasService],
})
export class AsaasModule {}