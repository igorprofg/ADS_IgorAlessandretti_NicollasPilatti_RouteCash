import { SituacaoPagamento } from '@prisma/client';
import { IsEnum, IsOptional, Matches } from 'class-validator';

// HU54: atualizar a situação de um pagamento
export class AtualizarSituacaoPagamentoDto {
  @IsEnum(SituacaoPagamento, { message: 'situacao deve ser PAGO, PENDENTE, VENCIDO ou CANCELADO' })
  situacao: SituacaoPagamento;

  // Só para PAGO. Se for PAGO e não vier, vale a data de hoje.
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'data_pagamento deve estar no formato AAAA-MM-DD',
  })
  data_pagamento?: string;
}