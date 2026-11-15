import {
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';

import { AsaasService } from './asaas.service';

@Controller('asaas')
export class AsaasController {
  constructor(
    private readonly asaasService: AsaasService,
  ) {}

  @Get('teste')
  async testarConexao() {
    return this.asaasService.testarConexao();
  }

  // ============================================
  // TEMPORÁRIO - TESTE SANDBOX
  // ============================================
  //
  // Depois vamos remover esta rota e utilizar
  // o usuário autenticado pelo JWT.
  //
  @Post('customer/:usuarioId')
  async criarOuObterCustomer(
    @Param('usuarioId', new ParseUUIDPipe())
    usuarioId: string,
  ) {
    return this.asaasService.obterOuCriarCliente(
      usuarioId,
    );
  }
}