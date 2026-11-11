import { Module } from '@nestjs/common';
import { AssinaturasModule } from '../assinaturas/assinaturas.module';
import { PlanosController } from './planos.controller';
import { PlanosService } from './planos.service';

@Module({
  imports: [AssinaturasModule],
  controllers: [PlanosController],
  providers: [PlanosService],
})
export class PlanosModule {}