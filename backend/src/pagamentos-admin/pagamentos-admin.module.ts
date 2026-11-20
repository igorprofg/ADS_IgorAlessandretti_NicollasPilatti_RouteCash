import { Module } from '@nestjs/common';
import { PagamentosAdminController } from './pagamentos-admin.controller';
import { PagamentosAdminService } from './pagamentos-admin.service';

@Module({
  controllers: [PagamentosAdminController],
  providers: [PagamentosAdminService],
})
export class PagamentosAdminModule {}