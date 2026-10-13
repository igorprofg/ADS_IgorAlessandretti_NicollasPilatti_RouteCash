import { Module } from '@nestjs/common';
import { GanhosController } from './ganhos.controller';
import { GanhosService } from './ganhos.service';

@Module({
  controllers: [GanhosController],
  providers: [GanhosService],
})
export class GanhosModule {}