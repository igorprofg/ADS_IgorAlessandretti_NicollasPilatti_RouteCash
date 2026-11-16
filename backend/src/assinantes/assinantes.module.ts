import { Module } from '@nestjs/common';
import { AssinantesController } from './assinantes.controller';
import { AssinantesService } from './assinantes.service';

@Module({
  controllers: [AssinantesController],
  providers: [AssinantesService],
})
export class AssinantesModule {}