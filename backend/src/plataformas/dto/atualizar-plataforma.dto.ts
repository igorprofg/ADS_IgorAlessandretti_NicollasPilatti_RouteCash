import { IsNotEmpty, IsString } from 'class-validator';

export class AtualizarPlataformaDto {
  @IsNotEmpty({ message: 'O nome da plataforma é obrigatório' })
  @IsString()
  nome: string;
}