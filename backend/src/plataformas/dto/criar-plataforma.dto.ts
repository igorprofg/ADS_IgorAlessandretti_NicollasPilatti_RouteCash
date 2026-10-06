import { IsNotEmpty, IsString } from 'class-validator';

export class CriarPlataformaDto {
  @IsNotEmpty({ message: 'O nome da plataforma é obrigatório' })
  @IsString()
  nome: string;
}