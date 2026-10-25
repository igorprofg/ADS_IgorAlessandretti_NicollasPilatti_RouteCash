import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JornadasService } from './jornadas.service';
import { IniciarJornadaDto } from './dto/iniciar-jornada.dto';
import { LancarJornadaManualDto } from './dto/lancar-jornada-manual.dto';
import { FinalizarJornadaDto } from './dto/finalizar-jornada.dto';
import { AtualizarJornadaDto } from './dto/atualizar-jornada.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@UseGuards(JwtAuthGuard)
@Controller('jornadas')
export class JornadasController {
  constructor(private readonly jornadasService: JornadasService) {}

  @Post('iniciar')
  iniciar(@UsuarioAtual() usuarioId: string, @Body() dto: IniciarJornadaDto) {
    return this.jornadasService.iniciar(usuarioId, dto);
  }

  @Post('manual')
  lancarManual(
    @UsuarioAtual() usuarioId: string,
    @Body() dto: LancarJornadaManualDto,
  ) {
    return this.jornadasService.lancarManual(usuarioId, dto);
  }

  @Get()
  listar(@UsuarioAtual() usuarioId: string) {
    return this.jornadasService.findAll(usuarioId);
  }

  // ATENÇÃO: rotas fixas (como "em-andamento") precisam vir ANTES de ':id',
  // senão o Nest leria "em-andamento" como se fosse um id
  @Get('em-andamento')
  emAndamento(@UsuarioAtual() usuarioId: string) {
    return this.jornadasService.findEmAndamento(usuarioId);
  }

  @Get(':id')
  buscarUma(
    @UsuarioAtual() usuarioId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.jornadasService.findOne(usuarioId, id);
  }

  @Patch(':id/finalizar')
  finalizar(
    @UsuarioAtual() usuarioId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: FinalizarJornadaDto,
  ) {
    return this.jornadasService.finalizar(usuarioId, id, dto);
  }

  @Patch(':id')
  atualizar(
    @UsuarioAtual() usuarioId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AtualizarJornadaDto,
  ) {
    return this.jornadasService.update(usuarioId, id, dto);
  }

  @Delete(':id')
  remover(
    @UsuarioAtual() usuarioId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.jornadasService.remove(usuarioId, id);
  }
}