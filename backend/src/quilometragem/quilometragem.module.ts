import { Module } from '@nestjs/common';
import { QuilometragemController } from './quilometragem.controller';
import { QuilometragemService } from './quilometragem.service';

@Module({
  controllers: [QuilometragemController],
  providers: [QuilometragemService],
})
export class QuilometragemModule {}