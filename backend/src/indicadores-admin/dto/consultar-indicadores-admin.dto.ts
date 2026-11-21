import { IsOptional, Matches } from 'class-validator';

const FORMATO_DATA = /^\d{4}-\d{2}-\d{2}$/;

// Filtros de GET /admin/indicadores. Sem período = todos os registros.
export class ConsultarIndicadoresAdminDto {
  @IsOptional()
  @Matches(FORMATO_DATA, { message: 'inicio deve estar no formato AAAA-MM-DD' })
  inicio?: string;

  @IsOptional()
  @Matches(FORMATO_DATA, { message: 'fim deve estar no formato AAAA-MM-DD' })
  fim?: string;
}