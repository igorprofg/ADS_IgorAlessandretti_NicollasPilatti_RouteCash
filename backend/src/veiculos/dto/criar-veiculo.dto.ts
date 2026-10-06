import { IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CriarVeiculoDto {
  @IsNotEmpty({ message: 'A marca é obrigatória' })
  @IsString()
  marca: string;

  @IsNotEmpty({ message: 'O modelo é obrigatório' })
  @IsString()
  modelo: string;

  @IsInt({ message: 'O ano deve ser um número inteiro' })
  @Min(1950, { message: 'Ano inválido' })
  ano: number;

  @IsNotEmpty({ message: 'O combustível é obrigatório' })
  @IsString()
  combustivel: string;

  @IsNumber({}, { message: 'O consumo médio deve ser um número' })
  @Min(0.1, { message: 'O consumo médio deve ser maior que zero' })
  consumo_medio: number;

  @IsOptional()
  @IsString()
  placa?: string;
}