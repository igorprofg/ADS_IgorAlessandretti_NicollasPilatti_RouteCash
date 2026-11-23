
import { Module } from '@nestjs/common';
import { DespesasController } from './despesas.controller';
import { DespesasService } from './despesas.service';
import { AssinaturaAtivaGuard } from '../common/guards/assinatura-ativa.guard';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [DespesasController],
  providers: [DespesasService, AssinaturaAtivaGuard],
})
export class DespesasModule {}
