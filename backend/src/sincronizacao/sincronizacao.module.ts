
import { Module } from '@nestjs/common';
import { SincronizacaoController } from './sincronizacao.controller';
import { SincronizacaoService } from './sincronizacao.service';
import { AssinaturaAtivaGuard } from '../common/guards/assinatura-ativa.guard';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [SincronizacaoController],
  providers: [SincronizacaoService, AssinaturaAtivaGuard],
})
export class SincronizacaoModule {}
