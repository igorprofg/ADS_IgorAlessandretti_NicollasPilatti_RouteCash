import { IsIn, IsUUID } from 'class-validator';

export class ExclusaoSincronizadaDto {
  @IsIn(['ganho', 'despesa', 'jornada'], {
    message: 'entidade deve ser ganho, despesa ou jornada',
  })
  entidade: 'ganho' | 'despesa' | 'jornada';

  @IsUUID('4', { message: 'id inválido' })
  id: string;
}