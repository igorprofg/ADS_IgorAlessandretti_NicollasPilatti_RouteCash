import { Module } from '@nestjs/common';
import { AssinaturasAdminController } from './assinaturas-admin.controller';
import { AssinaturasAdminService } from './assinaturas-admin.service';

@Module({
  controllers: [AssinaturasAdminController],
  providers: [AssinaturasAdminService],
})
export class AssinaturasAdminModule {}