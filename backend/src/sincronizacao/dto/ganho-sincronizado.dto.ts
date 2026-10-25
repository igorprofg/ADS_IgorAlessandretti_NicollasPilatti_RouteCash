import {
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
} from 'class-validator';
import { FORMATO_DATA, FORMATO_DATA_HORA, MSG_DATA_HORA } from './formatos';

// Estado completo de um ganho, como está no app
export class GanhoSincronizadoDto {
  @IsUUID('4', { message: 'id_ganho inválido' })
  id_ganho: string;

  @IsUUID('4', { message: 'id_veiculo inválido' })
  id_veiculo: string;

  @IsUUID('4', { message: 'id_plataforma inválido' })
  id_plataforma: string;

  @IsNumber({ maxDecimalPlaces: 2 }, { message: 'valor deve ser um número com até 2 casas decimais' })
  @IsPositive({ message: 'valor deve ser maior que zero' })
  @Max(9999999999.99, { message: 'valor acima do limite permitido' })
  valor: number;

  @Matches(FORMATO_DATA, { message: 'data deve estar no formato AAAA-MM-DD' })
  data: string;

  @IsOptional()
  @IsString()
  @MaxLength(255, { message: 'observacao deve ter no máximo 255 caracteres' })
  observacao?: string | null;

  // Momento da última alteração feita no app (usado para decidir conflitos)
  @Matches(FORMATO_DATA_HORA, { message: `atualizado_em ${MSG_DATA_HORA}` })
  atualizado_em: string;
}