import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { IndicadoresService } from './indicadores.service';
import { ConsultaIndicadoresDto } from './dto/consulta-indicadores.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@UseGuards(JwtAuthGuard)
@Controller('indicadores')
export class IndicadoresController {
  constructor(private readonly indicadoresService: IndicadoresService) {}

  // Exemplos: GET /indicadores  |  GET /indicadores?inicio=2026-10-01&fim=2026-10-31
  @Get()
  calcular(
    @UsuarioAtual() usuarioId: string,
    @Query() filtro: ConsultaIndicadoresDto,
  ) {
    return this.indicadoresService.calcular(usuarioId, filtro);
  }
}