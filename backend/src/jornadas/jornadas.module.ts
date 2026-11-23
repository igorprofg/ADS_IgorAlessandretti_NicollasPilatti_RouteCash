
import { Module } from '@nestjs/common';
import { JornadasController } from './jornadas.controller';
import { JornadasService } from './jornadas.service';
import { AssinaturaAtivaGuard } from '../common/guards/assinatura-ativa.guard';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [JornadasController],
  providers: [JornadasService, AssinaturaAtivaGuard],
})
export class JornadasModule {}
