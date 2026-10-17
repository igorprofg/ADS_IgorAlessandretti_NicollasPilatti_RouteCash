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
import { QuilometragemService } from './quilometragem.service';
import { RegistrarQuilometragemDto } from './dto/registrar-quilometragem.dto';
import { AtualizarQuilometragemDto } from './dto/atualizar-quilometragem.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@UseGuards(JwtAuthGuard)
@Controller('quilometragem')
export class QuilometragemController {
  constructor(private readonly quilometragemService: QuilometragemService) {}

  @Post()
  registrar(
    @UsuarioAtual() usuarioId: string,
    @Body() dto: RegistrarQuilometragemDto,
  ) {
    return this.quilometragemService.registrar(usuarioId, dto);
  }

  @Get()
  listar(@UsuarioAtual() usuarioId: string) {
    return this.quilometragemService.findAll(usuarioId);
  }

  @Patch(':idJornada')
  atualizar(
    @UsuarioAtual() usuarioId: string,
    @Param('idJornada') idJornada: string,
    @Body() dto: AtualizarQuilometragemDto,
  ) {
    return this.quilometragemService.atualizar(usuarioId, idJornada, dto);
  }

  @Delete(':idJornada')
  remover(
    @UsuarioAtual() usuarioId: string,
    @Param('idJornada') idJornada: string,
  ) {
    return this.quilometragemService.remover(usuarioId, idJornada);
  }
}