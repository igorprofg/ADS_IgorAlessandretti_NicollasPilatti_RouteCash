import { Module } from '@nestjs/common';
import { IndicadoresAdminController } from './indicadores-admin.controller';
import { IndicadoresAdminService } from './indicadores-admin.service';

@Module({
  controllers: [IndicadoresAdminController],
  providers: [IndicadoresAdminService],
})
export class IndicadoresAdminModule {}