import { Transform } from 'class-transformer';
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Max,
  MaxLength,
} from 'class-validator';
import { PERIODOS_COBRANCA } from '../../common/periodo-cobranca';
import { normalizarPeriodo } from './criar-plano.dto';

// HU46: todos os campos são opcionais; só o que for enviado é alterado.
// A situação (ativo/inativo) NÃO se altera aqui: tem rotas próprias (HU47).
export class AtualizarPlanoDto {
  @IsOptional()
  @IsString()
  @MaxLength(60, { message: 'O nome deve ter no máximo 60 caracteres' })
  nome?: string;

  @IsOptional()
  @IsNumber(
    { maxDecimalPlaces: 2 },
    { message: 'O valor deve ser um número com até 2 casas decimais' },
  )
  @IsPositive({ message: 'O valor deve ser maior que zero' })
  @Max(99999.99, { message: 'Valor acima do limite permitido' })
  valor?: number;

  @IsOptional()
  @Transform(normalizarPeriodo)
  @IsIn(PERIODOS_COBRANCA, {
    message: `O período de cobrança deve ser: ${PERIODOS_COBRANCA.join(', ')}`,
  })
  periodo_cobranca?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000, { message: 'Os benefícios devem ter no máximo 2000 caracteres' })
  beneficios?: string;
}