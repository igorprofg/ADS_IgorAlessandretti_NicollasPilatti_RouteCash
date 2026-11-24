import type { Assinatura } from './assinaturas.tipos';

// Resposta de GET e PATCH /usuarios/me/dados-pagamento
export interface DadosPagamentoUsuario {
  cpf_cnpj: string | null;
  celular: string | null;
  cep: string | null;
  logradouro: string | null;
  numero_endereco: string | null;
  complemento: string | null;
  bairro: string | null;
  completo: boolean; // já dá para iniciar o checkout
}

// Corpo de PATCH /usuarios/me/dados-pagamento
export interface SalvarDadosPagamento {
  cpf_cnpj: string;
  celular?: string;
  cep: string;
  logradouro: string;
  numero_endereco: string;
  complemento?: string;
  bairro: string;
}

// Resposta de POST /assinaturas/asaas
export interface ResultadoCheckout {
  assinatura: Assinatura;
  checkout_id: string;
  checkout_url: string;
  checkout_reutilizado: boolean;
}