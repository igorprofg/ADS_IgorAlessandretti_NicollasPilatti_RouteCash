import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JornadasService } from './jornadas.service';
import { IniciarJornadaDto } from './dto/iniciar-jornada.dto';
import { FinalizarJornadaDto } from './dto/finalizar-jornada.dto';
import { AtualizarJornadaDto } from './dto/atualizar-jornada.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@UseGuards(JwtAuthGuard)
@Controller('jornadas')
export class JornadasController{
    constructor(private readonly jornadasService: JornadasService) {}

    @Post('iniciar')
    iniciar(@UsuarioAtual() usuarioId: string, @Body() dto: IniciarJornadaDto) {
        return this.jornadasService.iniciar(usuarioId, dto);
    }

    @Get()
    listar(@UsuarioAtual() usuarioId: string) {
        return this.jornadasService.findAll(usuarioId);
    }

    // ATENÇÃO: precisa vir ANTES de ':id', senão "em-andamento" seria lido como um id
    @Get('em-andamento')
    emAndamento(@UsuarioAtual() usuarioId: string) {
        return this.jornadasService.findEmAndamento(usuarioId);
  }

    @Get(':id')
    buscarUma(@UsuarioAtual() usuarioId: string, @Param('id') id: string) {
        return this.jornadasService.findOne(usuarioId, id);
  }

    @Patch(':id/finalizar')
    finalizar(
    @UsuarioAtual() usuarioId: string,
    @Param('id') id: string,
    @Body() dto: FinalizarJornadaDto,
  ) {
    return this.jornadasService.finalizar(usuarioId, id, dto);
  }

  @Patch(':id') 
  atualizar(
    @UsuarioAtual() UsuarioId: string,
    @Param('id') id: string,
    @Body() dto: AtualizarJornadaDto,
  ){
    return this.jornadasService.update(UsuarioId, id, dto);
  }

}