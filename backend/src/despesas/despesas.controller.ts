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
import { DespesasService } from './despesas.service';
import { CriarDespesaDto } from './dto/criar-despesa.dto';
import { AtualizarDespesaDto } from './dto/atualizar-despesa.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@UseGuards(JwtAuthGuard)
@Controller('despesas')
export class DespesasController {
  constructor(private readonly despesasService: DespesasService) {}

  @Post()
  criar(@UsuarioAtual() usuarioId: string, @Body() dto: CriarDespesaDto) {
    return this.despesasService.create(usuarioId, dto);
  }

  @Get()
  listar(@UsuarioAtual() usuarioId: string) {
    return this.despesasService.findAll(usuarioId);
  }

  @Get(':id')
  buscarUma(@UsuarioAtual() usuarioId: string, @Param('id') id: string) {
    return this.despesasService.findOne(usuarioId, id);
  }

  @Patch(':id')
  atualizar(
    @UsuarioAtual() usuarioId: string,
    @Param('id') id: string,
    @Body() dto: AtualizarDespesaDto,
  ) {
    return this.despesasService.update(usuarioId, id, dto);
  }

  @Delete(':id')
  remover(@UsuarioAtual() usuarioId: string, @Param('id') id: string) {
    return this.despesasService.remove(usuarioId, id);
  }
}