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
import { VeiculosService } from './veiculos.service';
import { CriarVeiculoDto } from './dto/criar-veiculo.dto';
import { AtualizarVeiculoDto } from './dto/atualizar-veiculo.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

// Guard no controller inteiro: toda rota de veículo exige usuário autenticado
@UseGuards(JwtAuthGuard)
@Controller('veiculos')
export class VeiculosController {
  constructor(private readonly veiculosService: VeiculosService) {}

  @Post()
  criar(@UsuarioAtual() usuarioId: string, @Body() dto: CriarVeiculoDto) {
    return this.veiculosService.create(usuarioId, dto);
  }

  @Get()
  listar(@UsuarioAtual() usuarioId: string) {
    return this.veiculosService.findAll(usuarioId);
  }

  @Get(':id')
  buscarUm(@UsuarioAtual() usuarioId: string, @Param('id') id: string) {
    return this.veiculosService.findOne(usuarioId, id);
  }

  @Patch(':id')
  atualizar(
    @UsuarioAtual() usuarioId: string,
    @Param('id') id: string,
    @Body() dto: AtualizarVeiculoDto,
  ) {
    return this.veiculosService.update(usuarioId, id, dto);
  }

  @Delete(':id')
  remover(@UsuarioAtual() usuarioId: string, @Param('id') id: string) {
    return this.veiculosService.remove(usuarioId, id);
  }

  @Patch(':id/principal')
  definirPrincipal(
    @UsuarioAtual() usuarioId: string,
    @Param('id') id: string,
  ) {
    return this.veiculosService.definirPrincipal(usuarioId, id);
  }
}