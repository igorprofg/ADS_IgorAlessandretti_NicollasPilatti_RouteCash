import { IsDateString, IsNumber, IsPositive, IsUUID } from 'class-validator';
 
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
}
 