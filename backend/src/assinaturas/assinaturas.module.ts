import { Module } from '@nestjs/common';
import { AssinaturasController } from './assinaturas.controller';
import { AssinaturasService } from './assinaturas.service';

@Module({
  controllers: [AssinaturasController],
  providers: [AssinaturasService],
  exports: [AssinaturasService], // o módulo de planos usa para identificar o plano contratado
})
export class AssinaturasModule {}