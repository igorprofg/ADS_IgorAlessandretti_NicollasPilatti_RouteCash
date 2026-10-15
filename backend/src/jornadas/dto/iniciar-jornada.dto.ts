import { IsDateString, IsOptional, IsUUID } from 'class-validator';

export class IniciarJornadaDto {
  @IsUUID('4', { message: 'Veículo inválido' })
  id_veiculo: string;

  // HU22: se não for informado, usa o horário atual do servidor
  @IsOptional()
  @IsDateString({}, { message: 'Horário de início inválido' })
  inicio?: string;
}