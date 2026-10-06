import { IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class AtualizarVeiculoDto {
  @IsOptional()
  @IsString()
  marca?: string;

  @IsOptional()
  @IsString()
  modelo?: string;

  @IsOptional()
  @IsInt({ message: 'O ano deve ser um número inteiro' })
  @Min(1950, { message: 'Ano inválido' })
  ano?: number;

  @IsOptional()
  @IsString()
  combustivel?: string;

  @IsOptional()
  @IsNumber({}, { message: 'O consumo médio deve ser um número' })
  @Min(0.1, { message: 'O consumo médio deve ser maior que zero' })
  consumo_medio?: number;

  @IsOptional()
  @IsString()
  placa?: string;
}