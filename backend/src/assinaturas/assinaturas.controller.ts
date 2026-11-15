import {
  Body,
  Controller,
  Get,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';

import { AssinaturasService } from './assinaturas.service';
import { ContratarAssinaturaDto } from './dto/contratar-assinatura.dto';

import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { UsuarioAtual } from '../common/decorators/usuario-atual.decorator';

@UseGuards(JwtAuthGuard)
@Controller('assinaturas')
export class AssinaturasController {
  constructor(
    private readonly assinaturasService: AssinaturasService,
  ) {}

  // ============================================
  // HU37 - CONTRATAÇÃO MANUAL
  // ============================================
  //
  // Mantém o fluxo original do Route Cash.
  //
  // A assinatura é criada diretamente como ATIVA
  // e com origem MANUAL.
  //
  // Este endpoint pode continuar existindo para
  // uso administrativo ou enquanto o fluxo Asaas
  // ainda estiver em fase de implantação.
  //
  @Post()
  contratar(
    @UsuarioAtual() usuarioId: string,
    @Body() dto: ContratarAssinaturaDto,
  ) {
    return this.assinaturasService.contratar(
      usuarioId,
      dto,
    );
  }

  // ============================================
  // INÍCIO - TEMPORÁRIO PARA TESTES ASAAS SANDBOX
  // ============================================
  //
  // Esta rota foi criada para validar o fluxo:
  //
  // usuário autenticado
  //        ↓
  // plano selecionado
  //        ↓
  // Customer Asaas
  //        ↓
  // assinatura local PENDENTE
  //        ↓
  // Checkout Asaas
  //        ↓
  // checkout_url
  //
  // IMPORTANTE:
  //
  // O usuarioId NÃO vem pela URL.
  //
  // Ele é obtido diretamente do JWT através de:
  //
  // @UsuarioAtual()
  //
  // Isso evita que um usuário tente contratar
  // um plano utilizando o UUID de outra conta.
  //
  // Depois que o fluxo Asaas estiver concluído
  // e validado, esta rota poderá:
  //
  // 1. tornar-se a rota oficial de contratação;
  // ou
  // 2. substituir completamente o POST /assinaturas.
  //
  @Post('asaas')
  contratarComAsaas(
    @UsuarioAtual() usuarioId: string,
    @Body() dto: ContratarAssinaturaDto,
  ) {
    return this.assinaturasService.contratarComAsaas(
      usuarioId,
      dto,
    );
  }

  // ============================================
  // FIM - TEMPORÁRIO PARA TESTES ASAAS SANDBOX
  // ============================================

  // ============================================
  // HU38 - LISTAR ASSINATURAS
  // ============================================

  @Get()
  listar(
    @UsuarioAtual() usuarioId: string,
  ) {
    return this.assinaturasService.listar(
      usuarioId,
    );
  }

  // ============================================
  // HU38 - ASSINATURA ATUAL
  // ============================================

  @Get('atual')
  atual(
    @UsuarioAtual() usuarioId: string,
  ) {
    return this.assinaturasService.buscarAtual(
      usuarioId,
    );
  }

  // ============================================
  // HU39 - CANCELAR ASSINATURA ATUAL
  // ============================================

  @Patch('atual/cancelar')
  cancelar(
    @UsuarioAtual() usuarioId: string,
  ) {
    return this.assinaturasService.cancelarAtual(
      usuarioId,
    );
  }
}