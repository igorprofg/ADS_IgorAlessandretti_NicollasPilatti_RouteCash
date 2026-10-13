import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { CategoriasDespesaService } from './categorias-despesa.service';
import { CriarCategoriaDespesaDto } from './dto/criar-categoria-despesa.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@UseGuards(JwtAuthGuard)
@Controller('categorias-despesa')
export class CategoriasDespesaController {
  constructor(private readonly categoriasService: CategoriasDespesaService) {}

  @Get()
  listar(@UsuarioAtual() usuarioId: string) {
    return this.categoriasService.findAll(usuarioId);
  }

  @Post()
  criar(
    @UsuarioAtual() usuarioId: string,
    @Body() dto: CriarCategoriaDespesaDto,
  ) {
    return this.categoriasService.create(usuarioId, dto);
  }
}