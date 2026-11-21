import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { IndicadoresAdminService } from './indicadores-admin.service';
import { ConsultarIndicadoresAdminDto } from './dto/consultar-indicadores-admin.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdministradorGuard } from '../common/guards/administrador.guard';

// Área administrativa (RF19). Os indicadores financeiros do MOTORISTA ficam em /indicadores (RF10).
@UseGuards(JwtAuthGuard, AdministradorGuard)
@Controller('admin/indicadores')
export class IndicadoresAdminController {
  constructor(private readonly indicadoresAdminService: IndicadoresAdminService) {}

  @Get()
  obter(@Query() filtro: ConsultarIndicadoresAdminDto) {
    return this.indicadoresAdminService.obter(filtro);
  }
}