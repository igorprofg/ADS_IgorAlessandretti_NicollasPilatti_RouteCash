import { IsNumber, IsPositive, IsUUID, Max } from 'class-validator';

export class RegistrarQuilometragemDto {
  @IsUUID('4', { message: 'Jornada inválida' })
  id_jornada: string;

  @IsNumber(
    { maxDecimalPlaces: 2 },
    { message: 'A quilometragem deve ser um número com até 2 casas decimais' },
  )
  @IsPositive({ message: 'A quilometragem deve ser maior que zero' })
  @Max(999999.99, { message: 'Quilometragem acima do limite permitido' })
  km_rodados: number;
}