import { IsNumber, IsPositive, Max } from 'class-validator';

export class AtualizarQuilometragemDto {
  @IsNumber(
    { maxDecimalPlaces: 2 },
    { message: 'A quilometragem deve ser um número com até 2 casas decimais' },
  )
  @IsPositive({ message: 'A quilometragem deve ser maior que zero' })
  @Max(999999.99, { message: 'Quilometragem acima do limite permitido' })
  km_rodados: number;
}