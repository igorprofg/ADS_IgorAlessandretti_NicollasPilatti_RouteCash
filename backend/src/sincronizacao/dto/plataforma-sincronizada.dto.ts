import { IsBoolean, IsString, IsUUID, Matches, MaxLength } from 'class-validator';
import { FORMATO_DATA_HORA, MSG_DATA_HORA } from './formatos';

// Estado completo de uma plataforma, como está no app.
// O campo "padrao" não é enviado: quem cria as plataformas padrão é o servidor.
// O limite do nome segue a coluna do banco (60).
export class PlataformaSincronizadaDto {
  @IsUUID('4', { message: 'id_plataforma inválido' })
  id_plataforma: string;

  @IsString()
  @MaxLength(60, { message: 'nome deve ter no máximo 60 caracteres' })
  nome: string;

  @IsBoolean({ message: 'ativa deve ser verdadeiro ou falso' })
  ativa: boolean;

  @Matches(FORMATO_DATA_HORA, { message: `atualizado_em ${MSG_DATA_HORA}` })
  atualizado_em: string;
}