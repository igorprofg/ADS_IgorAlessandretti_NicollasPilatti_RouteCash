import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { FORMATO_DATA_HORA, MSG_DATA_HORA } from './formatos';

// Estado completo de um veículo, como está no app.
// Os limites de tamanho seguem as colunas do banco (marca/modelo 50, combustivel 30, placa 10).
export class VeiculoSincronizadoDto {
  @IsUUID('4', { message: 'id_veiculo inválido' })
  id_veiculo: string;

  @IsString()
  @MaxLength(50, { message: 'marca deve ter no máximo 50 caracteres' })
  marca: string;

  @IsString()
  @MaxLength(50, { message: 'modelo deve ter no máximo 50 caracteres' })
  modelo: string;

  @IsInt({ message: 'ano deve ser um número inteiro' })
  @Min(1950, { message: 'ano inválido' })
  @Max(2100, { message: 'ano inválido' })
  ano: number;

  @IsString()
  @MaxLength(30, { message: 'combustivel deve ter no máximo 30 caracteres' })
  combustivel: string;

  @IsNumber(
    { maxDecimalPlaces: 2 },
    { message: 'consumo_medio deve ser um número com até 2 casas decimais' },
  )
  @IsPositive({ message: 'consumo_medio deve ser maior que zero' })
  @Max(999.99, { message: 'consumo_medio acima do limite permitido' })
  consumo_medio: number;

  @IsOptional()
  @IsString()
  @MaxLength(10, { message: 'placa deve ter no máximo 10 caracteres' })
  placa?: string | null;

  @IsBoolean({ message: 'ativo deve ser verdadeiro ou falso' })
  ativo: boolean;

  @IsBoolean({ message: 'principal deve ser verdadeiro ou falso' })
  principal: boolean;

  @Matches(FORMATO_DATA_HORA, { message: `atualizado_em ${MSG_DATA_HORA}` })
  atualizado_em: string;
}