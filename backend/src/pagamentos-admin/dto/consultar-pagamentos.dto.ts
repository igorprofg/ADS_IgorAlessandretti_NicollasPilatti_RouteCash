import { SituacaoPagamento } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

// Filtros de GET /admin/pagamentos (query string)
export class ConsultarPagamentosDto {
  @IsOptional()
  @IsEnum(SituacaoPagamento, { message: 'situacao deve ser PAGO, PENDENTE, VENCIDO ou CANCELADO' })
  situacao?: SituacaoPagamento;

  // Pesquisa por nome ou e-mail do usuário, ou nome do plano
  @IsOptional()
  @IsString()
  @MaxLength(150, { message: 'busca deve ter no máximo 150 caracteres' })
  busca?: string;

  // Só os pagamentos de uma assinatura
  @IsOptional()
  @IsUUID('4', { message: 'id_assinatura inválido' })
  id_assinatura?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: 'pagina deve ser um número inteiro' })
  @Min(1, { message: 'pagina deve ser maior ou igual a 1' })
  pagina?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: 'limite deve ser um número inteiro' })
  @Min(1, { message: 'limite deve ser maior ou igual a 1' })
  @Max(100, { message: 'limite deve ser no máximo 100' })
  limite?: number;
}