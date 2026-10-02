import { Body, Controller, Delete, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { UsuariosService } from './usuarios.service';
import { CriarUsuarioDto } from './dto/criar-usuario.dto';
import { AtualizarUsuarioDto } from './dto/atualizar-usuario.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@Controller('usuarios')
export class UsuariosController {
  constructor(private readonly usuariosService: UsuariosService) {}

  @Post()
  criar(@Body() dto: CriarUsuarioDto) {
    return this.usuariosService.create(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  buscarPerfil(@UsuarioAtual() usuarioId: string) {
    return this.usuariosService.findOne(usuarioId);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me')
  atualizarPerfil(
    @UsuarioAtual() usuarioId: string,
    @Body() dto: AtualizarUsuarioDto,
  ) {
    return this.usuariosService.update(usuarioId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me')
  excluirConta(@UsuarioAtual() usuarioId: string) {
    return this.usuariosService.remove(usuarioId);
  }
}