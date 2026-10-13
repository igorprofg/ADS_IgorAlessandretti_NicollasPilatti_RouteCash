import { IsDateString, IsOptional } from 'class-validator';

// HU17: a duplicação mantém os dados originais, exceto a data, que pode ser ajustada antes de salvar
export class DuplicarGanhoDto {
  @IsOptional()
  @IsDateString({}, { message: 'Data inválida' })
  data?: string;
}