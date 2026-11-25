import { Transform } from 'class-transformer';
import { IsNotEmpty, IsOptional, IsString, Matches, MaxLength } from 'class-validator';

const somenteDigitos = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.replace(/\D/g, '') : value;

const textoAparado = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

const textoOuVazio = ({ value }: { value: unknown }) => {
  if (typeof value !== 'string') return value;
  const texto = value.trim();
  return texto === '' ? undefined : texto;
};

// Dados que o Asaas exige para criar o cliente e cobrar (checkout). Tudo é guardado só com números
// onde faz sentido (CPF/CNPJ, celular e CEP).
export class SalvarDadosPagamentoDto {
  @Transform(somenteDigitos)
  @Matches(/^(\d{11}|\d{14})$/, { message: 'CPF/CNPJ deve ter 11 ou 14 dígitos' })
  cpf_cnpj: string;

  // Obrigatório: o Asaas recusa o checkout sem o telefone do cliente
  @Transform(somenteDigitos)
  @Matches(/^\d{10,11}$/, {
    message: 'O celular é obrigatório e deve ter 10 ou 11 dígitos, com DDD',
  })
  celular: string;

  @Transform(somenteDigitos)
  @Matches(/^\d{8}$/, { message: 'O CEP deve ter 8 dígitos' })
  cep: string;

  @Transform(textoAparado)
  @IsString()
  @IsNotEmpty({ message: 'O logradouro é obrigatório' })
  @MaxLength(150, { message: 'O logradouro deve ter no máximo 150 caracteres' })
  logradouro: string;

  @Transform(textoAparado)
  @IsString()
  @IsNotEmpty({ message: 'O número do endereço é obrigatório' })
  @MaxLength(20, { message: 'O número deve ter no máximo 20 caracteres' })
  numero_endereco: string;

  @IsOptional()
  @Transform(textoOuVazio)
  @IsString()
  @MaxLength(100, { message: 'O complemento deve ter no máximo 100 caracteres' })
  complemento?: string;

  @Transform(textoAparado)
  @IsString()
  @IsNotEmpty({ message: 'O bairro é obrigatório' })
  @MaxLength(100, { message: 'O bairro deve ter no máximo 100 caracteres' })
  bairro: string;
}