import { SituacaoAssinatura } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

// Filtros de GET /admin/assinaturas (query string)
export class ConsultarAssinaturasDto {
    // Filtrar por situação da assinatura
    @IsOptional()
    @IsEnum(SituacaoAssinatura, {
        message: 'situacao deve ser PENDENTE, ATIVA, SUSPENSA ou CANCELADA',
    })
    situacao?: SituacaoAssinatura;

    // Pesquisa por nome ou e-mail do usuário, ou nome do plano
    @IsOptional()
    @IsString() 
    @MaxLength(150, {message: 'busca deve ter no máximo 150 caracteres'})
    busca?: string; 

    @IsOptional()
    @Type(() => Number)
    @IsInt({message: 'pagina deve ser um número inteiro'})
    @Min(1, {message: 'pagina deve ser maior ou igual a 1'})
    pagina?: number;

    @IsOptional()
    @Type(() => Number)
    @IsInt({ message: 'pagina deve ser um número inteiro'})
    @Min(1, { message: 'limite deve ser maior ou igual a 1'})
    @Max(100, {message: 'limite deve ser no máximo 100'})
    limite?: number; 
}

