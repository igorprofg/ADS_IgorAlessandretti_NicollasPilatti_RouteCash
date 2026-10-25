import { IsNumber, IsOptional, IsPositive, IsUUID, Matches, Max } from 'class-validator';
import { FORMATO_DATA_HORA, MSG_DATA_HORA } from './formatos';

// Estado completo de uma jornada, como está no app (fim nulo = jornada em andamento;
// km_rodados nulo = sem quilometragem registrada)
export class JornadaSincronizadaDto {
  @IsUUID('4', { message: 'id_jornada inválido' })
  id_jornada: string;

  @IsUUID('4', { message: 'id_veiculo inválido' })
  id_veiculo: string;

  @Matches(FORMATO_DATA_HORA, { message: `inicio ${MSG_DATA_HORA}` })
  inicio: string;

  @IsOptional()
  @Matches(FORMATO_DATA_HORA, { message: `fim ${MSG_DATA_HORA}` })
  fim?: string | null;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 }, { message: 'km_rodados deve ser um número com até 2 casas decimais' })
  @IsPositive({ message: 'km_rodados deve ser maior que zero' })
  @Max(999999.99, { message: 'km_rodados acima do limite permitido' })
  km_rodados?: number | null;

  @Matches(FORMATO_DATA_HORA, { message: `atualizado_em ${MSG_DATA_HORA}` })
  atualizado_em: string;
}