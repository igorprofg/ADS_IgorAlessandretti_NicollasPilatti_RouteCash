import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

// Filtros de GET /admin/assinantes (query string)
export class ConsultarAssinantesDto {
  @IsOptional()
  @IsString()
  @MaxLength(100, { message: 'nome deve ter no máximo 100 caracteres' })
  nome?: string;

  @IsOptional()
  @IsString()
  @MaxLength(150, { message: 'email deve ter no máximo 150 caracteres' })
  email?: string;

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