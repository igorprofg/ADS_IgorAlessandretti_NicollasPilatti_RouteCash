import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { GanhosService } from './ganhos.service';
import { CriarGanhoDto } from './dto/criar-ganho.dto';
import { AtualizarGanhoDto } from './dto/atualizar-ganho.dto';
import { DuplicarGanhoDto } from './dto/duplicar-ganho.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@UseGuards(JwtAuthGuard)
@Controller('ganhos')
export class GanhosController {
  constructor(private readonly ganhosService: GanhosService) {}

  @Post()
  criar(@UsuarioAtual() usuarioId: string, @Body() dto: CriarGanhoDto) {
    return this.ganhosService.create(usuarioId, dto);
  }

  @Get()
  listar(@UsuarioAtual() usuarioId: string) {
    return this.ganhosService.findAll(usuarioId);
  }

  @Get(':id')
  buscarUm(@UsuarioAtual() usuarioId: string, @Param('id') id: string) {
    return this.ganhosService.findOne(usuarioId, id);
  }

  @Patch(':id')
  atualizar(
    @UsuarioAtual() usuarioId: string,
    @Param('id') id: string,
    @Body() dto: AtualizarGanhoDto,
  ) {
    return this.ganhosService.update(usuarioId, id, dto);
  }

  @Delete(':id')
  remover(@UsuarioAtual() usuarioId: string, @Param('id') id: string) {
    return this.ganhosService.remove(usuarioId, id);
  }

  @Post(':id/duplicar')
  duplicar(
    @UsuarioAtual() usuarioId: string,
    @Param('id') id: string,
    @Body() dto: DuplicarGanhoDto,
  ) {
    return this.ganhosService.duplicar(usuarioId, id, dto);
  }
}