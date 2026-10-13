import { IsDateString, IsNumber, IsOptional, IsPositive, IsUUID } from 'class-validator';

export class AtualizarGanhoDto {
  @IsOptional()
  @IsUUID('4', { message: 'Veículo inválido' })
  id_veiculo?: string;

  @IsOptional()
  @IsUUID('4', { message: 'Plataforma inválida' })
  id_plataforma?: string;

  @IsOptional()
  @IsNumber({}, { message: 'O valor deve ser um número' })
  @IsPositive({ message: 'O valor deve ser maior que zero' })
  valor?: number;

  @IsOptional()
  @IsDateString({}, { message: 'Data inválida' })
  data?: string;
}