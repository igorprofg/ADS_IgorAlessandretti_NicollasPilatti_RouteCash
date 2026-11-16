import { Module } from '@nestjs/common';
import { PlanosAdminController } from './planos-admin.controller';
import { PlanosAdminService } from './planos-admin.service';

@Module({
  controllers: [PlanosAdminController],
  providers: [PlanosAdminService],
})
export class PlanosAdminModule {}