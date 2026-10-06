import { Module } from '@nestjs/common';
import { PlataformasController } from './plataformas.controller';
import { PlataformasService } from './plataformas.service';

@Module({
  controllers: [PlataformasController],
  providers: [PlataformasService],
})
export class PlataformasModule {}