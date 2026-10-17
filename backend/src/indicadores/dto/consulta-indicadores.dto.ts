import { IsOptional, Matches } from 'class-validator';

const FORMATO_DATA = /^\d{4}-\d{2}-\d{2}$/;

// HU30: filtro por período (AAAA-MM-DD). Sem filtro, o padrão é o dia atual.
export class ConsultaIndicadoresDto {
  @IsOptional()
  @Matches(FORMATO_DATA, { message: 'Data inicial inválida. Use o formato AAAA-MM-DD' })
  inicio?: string;

  @IsOptional()
  @Matches(FORMATO_DATA, { message: 'Data final inválida. Use o formato AAAA-MM-DD' })
  fim?: string;
}