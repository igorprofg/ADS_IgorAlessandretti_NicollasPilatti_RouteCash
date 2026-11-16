import type { SituacaoAssinatura } from './assinaturas.tipos';

// Situação do assinante (da conta do usuário)
export type StatusConta = 'ATIVO' | 'SUSPENSO' | 'BLOQUEADO';

export interface AssinaturaDoAssinante {
  id_assinatura: string;
  situacao: SituacaoAssinatura;
  data_inicio: string; // AAAA-MM-DD
  data_vencimento: string; // AAAA-MM-DD
  vencida: boolean;
  plano: { nome: string; valor: number; periodo_cobranca: string };
}

// Item de GET /admin/assinantes
export interface Assinante {
  id_usuario: string;
  nome: string;
  email: string;
  status_conta: StatusConta;
  data_cadastro: string; // data e hora ISO
  assinatura_atual: AssinaturaDoAssinante | null;
}

// Resposta de GET /admin/assinantes/:id e das ações (ativar, suspender, bloquear)
export interface AssinanteDetalhe extends Assinante {
  aceite_termos_em: string;
  data_atualizacao: string;
}

export interface PaginaAssinantes {
  itens: Assinante[];
  total: number;
  pagina: number;
  limite: number;
}

export interface FiltroAssinantes {
  nome: string;
  email: string;
  pagina: number;
}