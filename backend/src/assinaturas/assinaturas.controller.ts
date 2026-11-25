import {
  Body,
  Controller,
  Get,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';

import { AssinaturasService } from './assinaturas.service';
import { ContratarAssinaturaDto } from './dto/contratar-assinatura.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@UseGuards(JwtAuthGuard)
@Controller('assinaturas')
export class AssinaturasController {
  constructor(
    private readonly assinaturasService: AssinaturasService,
  ) {}

  // Contratação manual (assinatura PENDENTE até liberação pelo admin).
  @Post()
  contratarManual(
    @UsuarioAtual() usuarioId: string,
    @Body() dto: ContratarAssinaturaDto,
  ) {
    return this.assinaturasService.contratar(usuarioId, dto);
  }


  // Contratação pelo Asaas (assinatura PENDENTE até confirmação).
  @Post('asaas')
  contratarComAsaas(
    @UsuarioAtual() usuarioId: string,
    @Body() dto: ContratarAssinaturaDto,
  ) {
    return this.assinaturasService.contratarComAsaas(usuarioId, dto);
  }

  // Emite autorização assinada de uso offline por até 7 dias.
  // NÃO utiliza AssinaturaAtivaGuard aqui porque o próprio
  // serviço valida e retorna o erro de domínio adequado.
  @Get('autorizacao-offline')
  autorizacaoOffline(@UsuarioAtual() usuarioId: string) {
    return this.assinaturasService.emitirAutorizacaoOffline(usuarioId);
  }

  @Get()
  listar(@UsuarioAtual() usuarioId: string) {
    return this.assinaturasService.listar(usuarioId);
  }

  @Get('atual')
  atual(@UsuarioAtual() usuarioId: string) {
    return this.assinaturasService.buscarAtual(usuarioId);
  }

  // Atenção: cancelamento local não cancela recorrência no Asaas.
  @Patch('atual/cancelar')
  cancelar(@UsuarioAtual() usuarioId: string) {
    return this.assinaturasService.cancelarAtual(usuarioId);
  }
}
