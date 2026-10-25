import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import { SincronizacaoService } from './sincronizacao.service';
import { EnviarSincronizacaoDto } from './dto/enviar-sincronizacao.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@UseGuards(JwtAuthGuard)
@Controller('sincronizacao')
export class SincronizacaoController {
  constructor(private readonly sincronizacaoService: SincronizacaoService) {}

  // App -> servidor: lançamentos pendentes (e exclusões). Retorna um resultado por item.
  @HttpCode(HttpStatus.OK)
  @Post('enviar')
  enviar(
    @UsuarioAtual() usuarioId: string,
    @Body() dto: EnviarSincronizacaoDto,
  ) {
    return this.sincronizacaoService.enviar(usuarioId, dto);
  }

  // Servidor -> app: retrato completo dos dados do usuário
  @Get('baixar')
  baixar(@UsuarioAtual() usuarioId: string) {
    return this.sincronizacaoService.baixar(usuarioId);
  }
}