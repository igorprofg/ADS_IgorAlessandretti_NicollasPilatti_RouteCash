import { Body, Controller, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { AssinaturasService } from './assinaturas.service';
import { ContratarAssinaturaDto } from './dto/contratar-assinatura.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@UseGuards(JwtAuthGuard)
@Controller('assinaturas')
export class AssinaturasController {
  constructor(private readonly assinaturasService: AssinaturasService) {}

  @Post()
  contratar(
    @UsuarioAtual() usuarioId: string,
    @Body() dto: ContratarAssinaturaDto,
  ) {
    return this.assinaturasService.contratar(usuarioId, dto);
  }

  @Get()
  listar(@UsuarioAtual() usuarioId: string) {
    return this.assinaturasService.listar(usuarioId);
  }

  @Get('atual')
  atual(@UsuarioAtual() usuarioId: string) {
    return this.assinaturasService.buscarAtual(usuarioId);
  }

  @Patch('atual/cancelar')
  cancelar(@UsuarioAtual() usuarioId: string) {
    return this.assinaturasService.cancelarAtual(usuarioId);
  }
}