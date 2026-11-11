import { Controller, Get, Param, ParseUUIDPipe, UseGuards } from '@nestjs/common';
import { PlanosService } from './planos.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

// Consulta de planos pelo motorista (RF12). O cadastro e a edição de planos
// serão do administrador (RF16), em rotas próprias.
@UseGuards(JwtAuthGuard)
@Controller('planos')
export class PlanosController {
  constructor(private readonly planosService: PlanosService) {}

  @Get()
  listar(@UsuarioAtual() usuarioId: string) {
    return this.planosService.listar(usuarioId);
  }

  @Get(':id')
  buscarUm(
    @UsuarioAtual() usuarioId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.planosService.buscarUm(usuarioId, id);
  }
}