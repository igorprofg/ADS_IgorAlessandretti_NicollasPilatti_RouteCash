import { Transform } from 'class-transformer';
import {
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsPositive,
  IsString,
  Max,
  MaxLength,
} from 'class-validator';
import { PERIODOS_COBRANCA } from '../../common/periodo-cobranca';

// Aceita "mensal", " Mensal " etc. e guarda sempre em maiúsculas
export const normalizarPeriodo = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toUpperCase() : value;

export class CriarPlanoDto {
  @IsString()
  @IsNotEmpty({ message: 'O nome do plano é obrigatório' })
  @MaxLength(60, { message: 'O nome deve ter no máximo 60 caracteres' })
  nome: string;

  @IsNumber(
    { maxDecimalPlaces: 2 },
    { message: 'O valor deve ser um número com até 2 casas decimais' },
  )
  @IsPositive({ message: 'O valor deve ser maior que zero' })
  @Max(99999.99, { message: 'Valor acima do limite permitido' })
  valor: number;

  @Transform(normalizarPeriodo)
  @IsIn(PERIODOS_COBRANCA, {
    message: `O período de cobrança deve ser: ${PERIODOS_COBRANCA.join(', ')}`,
  })
  periodo_cobranca: string;

  // Um benefício por linha
  @IsString()
  @IsNotEmpty({ message: 'Informe as características e benefícios do plano' })
  @MaxLength(2000, { message: 'Os benefícios devem ter no máximo 2000 caracteres' })
  beneficios: string;
}