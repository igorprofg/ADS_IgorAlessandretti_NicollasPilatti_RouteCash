import { IsDateString, IsOptional } from 'class-validator';

export class FinalizarJornadaDto {
  // HU23: se não for informado, usa o horário atual do servidor
  @IsOptional()
  @IsDateString({}, { message: 'Horário final inválido' })
  fim?: string;
}