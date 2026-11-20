import { SituacaoPagamento } from '@prisma/client';
import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsPositive,
  IsUUID,
  Matches,
  Max,
} from 'class-validator';

const FORMATO_DATA = /^\d{4}-\d{2}-\d{2}$/;

// HU52: registrar pagamento (manual, feito pelo administrador)
export class RegistrarPagamentoDto {
  @IsUUID('4', { message: 'Assinatura inválida' })
  id_assinatura: string;

  @IsNumber(
    { maxDecimalPlaces: 2 },
    { message: 'O valor deve ser um número com até 2 casas decimais' },
  )
  @IsPositive({ message: 'O valor deve ser maior que zero' })
  @Max(99999.99, { message: 'Valor acima do limite permitido' })
  valor: number;

  @Matches(FORMATO_DATA, { message: 'data_vencimento deve estar no formato AAAA-MM-DD' })
  data_vencimento: string;

  // Se não informada, o pagamento nasce PENDENTE
  @IsOptional()
  @IsEnum(SituacaoPagamento, { message: 'situacao deve ser PAGO, PENDENTE, VENCIDO ou CANCELADO' })
  situacao?: SituacaoPagamento;

  // Só para pagamento PAGO. Se for PAGO e não vier, vale a data de hoje.
  @IsOptional()
  @Matches(FORMATO_DATA, { message: 'data_pagamento deve estar no formato AAAA-MM-DD' })
  data_pagamento?: string;
}