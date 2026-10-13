import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CriarCategoriaDespesaDto {
  @IsNotEmpty({ message: 'O nome da categoria é obrigatório' })
  @IsString()
  @MaxLength(50, { message: 'O nome da categoria deve ter no máximo 50 caracteres' })
  nome: string;
}