import { Controller, Get } from '@nestjs/common';
import { AsaasService } from './asaas.service';

@Controller('asaas')
export class AsaasController {
  constructor(private readonly asaasService: AsaasService) {}

  @Get('teste')
  async testarConexao() {
    return this.asaasService.testarConexao();
  }
}