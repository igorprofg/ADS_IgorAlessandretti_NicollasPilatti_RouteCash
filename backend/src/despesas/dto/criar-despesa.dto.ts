import {
  IsDateString,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

export class CriarDespesaDto {
  @IsUUID('4', { message: 'Veículo inválido' })
  id_veiculo: string;

  @IsUUID('4', { message: 'Categoria inválida' })
  id_categoria: string;

  @IsNumber({}, { message: 'O valor deve ser um número' })
  @IsPositive({ message: 'O valor deve ser maior que zero' })
  valor: number;

  @IsDateString({}, { message: 'Data inválida' })
  data: string;

  // Ex.: "Coxinha na padaria"
  @IsOptional()
  @IsString()
  @MaxLength(255, { message: 'A observação deve ter no máximo 255 caracteres' })
  observacao?: string;
}