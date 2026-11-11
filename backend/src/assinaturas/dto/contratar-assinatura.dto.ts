import { IsUUID } from 'class-validator';

export class ContratarAssinaturaDto {
  @IsUUID('4', { message: 'Plano inválido' })
  id_plano: string;
}