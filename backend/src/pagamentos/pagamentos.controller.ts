import { Controller, Get, UseGuards } from '@nestjs/common';
import { PagamentosService } from './pagamentos.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

// Consulta de pagamentos pelo motorista (RF14). O registro e a atualização
// dos pagamentos serão do administrador (RF18), em rotas próprias.
@UseGuards(JwtAuthGuard)
@Controller('pagamentos')
export class PagamentosController {
  constructor(private readonly pagamentosService: PagamentosService) {}

  @Get()
  listar(@UsuarioAtual() usuarioId: string) {
    return this.pagamentosService.listar(usuarioId);
  }
}