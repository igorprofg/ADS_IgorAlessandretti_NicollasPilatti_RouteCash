import { ArrayMaxSize, IsArray, IsObject, IsOptional } from 'class-validator';

// Aqui só se valida a "casca" do pedido. Cada item é validado separadamente no service,
// assim um item inválido gera erro só pra ele e não trava o lote inteiro.
// Limite de 50 itens por lista em cada chamada (se tiver mais, o app envia em várias chamadas).
export class EnviarSincronizacaoDto {
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50, { message: 'Envie no máximo 50 ganhos por chamada' })
  @IsObject({ each: true })
  ganhos?: Record<string, unknown>[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50, { message: 'Envie no máximo 50 despesas por chamada' })
  @IsObject({ each: true })
  despesas?: Record<string, unknown>[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50, { message: 'Envie no máximo 50 jornadas por chamada' })
  @IsObject({ each: true })
  jornadas?: Record<string, unknown>[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50, { message: 'Envie no máximo 50 exclusões por chamada' })
  @IsObject({ each: true })
  exclusoes?: Record<string, unknown>[];
}