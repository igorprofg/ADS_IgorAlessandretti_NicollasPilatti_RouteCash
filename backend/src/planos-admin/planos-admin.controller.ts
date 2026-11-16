import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { PlanosAdminService } from './planos-admin.service';
import { CriarPlanoDto } from './dto/criar-plano.dto';
import { AtualizarPlanoDto } from './dto/atualizar-plano.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdministradorGuard } from '../common/guards/administrador.guard';

// Área administrativa (RF16). O motorista consulta os planos em /planos (RF12).
@UseGuards(JwtAuthGuard, AdministradorGuard)
@Controller('admin/planos')
export class PlanosAdminController {
  constructor(private readonly planosAdminService: PlanosAdminService) {}

  @Get()
  listar() {
    return this.planosAdminService.listar();
  }

  @Get(':id')
  buscarUm(@Param('id', ParseUUIDPipe) id: string) {
    return this.planosAdminService.buscarUm(id);
  }

  @Post()
  criar(@Body() dto: CriarPlanoDto) {
    return this.planosAdminService.criar(dto);
  }

  @Patch(':id')
  atualizar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AtualizarPlanoDto,
  ) {
    return this.planosAdminService.atualizar(id, dto);
  }

  @Patch(':id/ativar')
  ativar(@Param('id', ParseUUIDPipe) id: string) {
    return this.planosAdminService.ativar(id);
  }

  @Patch(':id/inativar')
  inativar(@Param('id', ParseUUIDPipe) id: string) {
    return this.planosAdminService.inativar(id);
  }
}