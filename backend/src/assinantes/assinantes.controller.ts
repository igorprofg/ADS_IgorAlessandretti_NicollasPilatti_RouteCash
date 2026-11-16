import {
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AssinantesService } from './assinantes.service';
import { ConsultarAssinantesDto } from './dto/consultar-assinantes.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdministradorGuard } from '../common/guards/administrador.guard';

// Área administrativa (RF15): todas as rotas exigem login E perfil de administrador.
// Rotas de admin ficam sob o prefixo /admin, separadas das do motorista.
@UseGuards(JwtAuthGuard, AdministradorGuard)
@Controller('admin/assinantes')
export class AssinantesController {
  constructor(private readonly assinantesService: AssinantesService) {}

  @Get()
  listar(@Query() filtro: ConsultarAssinantesDto) {
    return this.assinantesService.listar(filtro);
  }

  @Get(':id')
  buscarUm(@Param('id', ParseUUIDPipe) id: string) {
    return this.assinantesService.buscarUm(id);
  }

  @Patch(':id/ativar')
  ativar(@Param('id', ParseUUIDPipe) id: string) {
    return this.assinantesService.ativar(id);
  }

  @Patch(':id/suspender')
  suspender(@Param('id', ParseUUIDPipe) id: string) {
    return this.assinantesService.suspender(id);
  }

  @Patch(':id/bloquear')
  bloquear(@Param('id', ParseUUIDPipe) id: string) {
    return this.assinantesService.bloquear(id);
  }
}