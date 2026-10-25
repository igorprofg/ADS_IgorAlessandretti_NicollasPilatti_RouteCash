import {
  IsDateString,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

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

  // Enviar "" (ou null) limpa a observação; não enviar mantém a atual
  @IsOptional()
  @IsString()
  @MaxLength(255, { message: 'A observação deve ter no máximo 255 caracteres' })
  observacao?: string | null;
}