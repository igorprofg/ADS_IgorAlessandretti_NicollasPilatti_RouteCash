import { IsDateString, IsOptional } from 'class-validator';

export class AtualizarJornadaDto {
  @IsOptional()
  @IsDateString({}, { message: 'Horário de início inválido' })
  inicio?: string;

  @IsOptional()
  @IsDateString({}, { message: 'Horário final inválido' })
  fim?: string;
}