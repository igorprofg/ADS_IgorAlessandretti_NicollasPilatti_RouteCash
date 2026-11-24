import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { DadosPagamentoService } from './dados-pagamento.service';
import { SalvarDadosPagamentoDto } from './dto/salvar-dados-pagamento.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

// Só o próprio usuário lê e altera os seus dados (o id vem do token, nunca da URL)
@UseGuards(JwtAuthGuard)
@Controller('usuarios/me/dados-pagamento')
export class DadosPagamentoController {
  constructor(private readonly dadosPagamentoService: DadosPagamentoService) {}

  @Get()
  obter(@UsuarioAtual() usuarioId: string) {
    return this.dadosPagamentoService.obter(usuarioId);
  }

  @Patch()
  salvar(@UsuarioAtual() usuarioId: string, @Body() dto: SalvarDadosPagamentoDto) {
    return this.dadosPagamentoService.salvar(usuarioId, dto);
  }
}