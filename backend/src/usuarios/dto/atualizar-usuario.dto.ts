import { IsOptional, IsString } from 'class-validator';

// RN13: campos definidos como imutáveis (email, tipo_usuario) não podem ser alterados aqui
export class AtualizarUsuarioDto {
  @IsOptional()
  @IsString()
  nome?: string;
}