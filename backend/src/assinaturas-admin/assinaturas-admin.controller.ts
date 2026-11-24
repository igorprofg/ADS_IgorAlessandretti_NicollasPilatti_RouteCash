import {
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AssinaturasAdminService } from './assinaturas-admin.service';
import { ConsultarAssinaturasDto } from './dto/consultar-assinaturas.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdministradorGuard } from '../common/guards/administrador.guard';

// Área administrativa (RF17). O motorista usa /assinaturas (RF13).
@UseGuards(JwtAuthGuard, AdministradorGuard)
@Controller('admin/assinaturas')
export class AssinaturasAdminController {
  constructor(private readonly assinaturasAdminService: AssinaturasAdminService) {}

  @Get()
  listar(@Query() filtro: ConsultarAssinaturasDto) {
    return this.assinaturasAdminService.listar(filtro);
  }

  @Get(':id')
  buscarUm(@Param('id', ParseUUIDPipe) id: string) {
    return this.assinaturasAdminService.buscarUm(id);
  }

  @Patch(':id/ativar')
  ativar(@Param('id', ParseUUIDPipe) id: string) {
    return this.assinaturasAdminService.ativar(id);
  }

  @Patch(':id/suspender')
  suspender(@Param('id', ParseUUIDPipe) id: string) {
    return this.assinaturasAdminService.suspender(id);
  }

  @Patch(':id/reativar')
  reativar(@Param('id', ParseUUIDPipe) id: string) {
    return this.assinaturasAdminService.reativar(id);
  }

  @Patch(':id/cancelar')
  cancelar(@Param('id', ParseUUIDPipe) id: string) {
    return this.assinaturasAdminService.cancelar(id);
  }
}