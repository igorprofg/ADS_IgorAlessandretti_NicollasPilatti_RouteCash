import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { PlataformasService } from './plataformas.service';
import { CriarPlataformaDto } from './dto/criar-plataforma.dto';
import { AtualizarPlataformaDto } from './dto/atualizar-plataforma.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@UseGuards(JwtAuthGuard)
@Controller('plataformas')
export class PlataformasController {
  constructor(private readonly plataformasService: PlataformasService) {}

  @Get()
  listar(@UsuarioAtual() usuarioId: string) {
    return this.plataformasService.findAll(usuarioId);
  }

  @Post()
  criar(@UsuarioAtual() usuarioId: string, @Body() dto: CriarPlataformaDto) {
    return this.plataformasService.create(usuarioId, dto);
  }

  @Patch(':id')
  atualizar(
    @UsuarioAtual() usuarioId: string,
    @Param('id') id: string,
    @Body() dto: AtualizarPlataformaDto,
  ) {
    return this.plataformasService.update(usuarioId, id, dto);
  }

  @Patch(':id/alternar-ativa')
  alternarAtiva(@UsuarioAtual() usuarioId: string, @Param('id') id: string) {
    return this.plataformasService.alternarAtiva(usuarioId, id);
  }
}