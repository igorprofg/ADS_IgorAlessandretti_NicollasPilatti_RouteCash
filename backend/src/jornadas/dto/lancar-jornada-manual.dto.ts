import { IsDateString, IsUUID } from 'class-validator';

// Para quem esqueceu de iniciar a jornada: informa direto o início e o fim
export class LancarJornadaManualDto {
  @IsUUID('4', { message: 'Veículo inválido' })
  id_veiculo: string;

  @IsDateString({}, { message: 'Horário de início inválido' })
  inicio: string;

  @IsDateString({}, { message: 'Horário final inválido' })
  fim: string;
}