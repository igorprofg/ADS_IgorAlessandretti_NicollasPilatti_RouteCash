import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { PagamentosAdminService } from './pagamentos-admin.service';
import { ConsultarPagamentosDto } from './dto/consultar-pagamentos.dto';
import { RegistrarPagamentoDto } from './dto/registrar-pagamento.dto';
import { AtualizarSituacaoPagamentoDto } from './dto/atualizar-situacao-pagamento.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdministradorGuard } from '../common/guards/administrador.guard';

// Área administrativa (RF18). O motorista consulta os próprios pagamentos em /pagamentos (RF14).
@UseGuards(JwtAuthGuard, AdministradorGuard)
@Controller('admin/pagamentos')
export class PagamentosAdminController {
  constructor(private readonly pagamentosAdminService: PagamentosAdminService) {}

  @Get()
  listar(@Query() filtro: ConsultarPagamentosDto) {
    return this.pagamentosAdminService.listar(filtro);
  }

  @Get(':id')
  buscarUm(@Param('id', ParseUUIDPipe) id: string) {
    return this.pagamentosAdminService.buscarUm(id);
  }

  @Post()
  registrar(@Body() dto: RegistrarPagamentoDto) {
    return this.pagamentosAdminService.registrar(dto);
  }

  @Patch(':id/situacao')
  atualizarSituacao(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AtualizarSituacaoPagamentoDto,
  ) {
    return this.pagamentosAdminService.atualizarSituacao(id, dto);
  }
}