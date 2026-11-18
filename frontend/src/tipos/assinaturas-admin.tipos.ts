import type { StatusConta } from './admin.tipos';

export type SituacaoAssinaturaAdmin = 'PENDENTE' | 'ATIVA' | 'SUSPENSA' | 'CANCELADA';
export type OrigemAssinatura = 'MANUAL' | 'ASAAS';

// Item de GET /admin/assinaturas
export interface AssinaturaAdmin {
  id_assinatura: string;
  situacao: SituacaoAssinaturaAdmin;
  origem: OrigemAssinatura;
  data_inicio: string | null; // AAAA-MM-DD (nula enquanto pendente)
  data_vencimento: string | null; // AAAA-MM-DD (nula enquanto pendente)
  vencida: boolean;
  data_cancelamento: string | null; // data e hora ISO
  data_cadastro: string;
  vinculo_asaas: boolean; // tem checkout ou assinatura criados no Asaas
  usuario: { id_usuario: string; nome: string; email: string; status_conta: StatusConta };
  plano: { id_plano: string; nome: string; valor: number; periodo_cobranca: string };
}

// Resposta de GET /admin/assinaturas/:id e das ações (suspender, reativar, cancelar)
export interface AssinaturaAdminDetalhe extends AssinaturaAdmin {
  asaas_checkout_id: string | null;
  asaas_subscription_id: string | null;
}

export interface PaginaAssinaturasAdmin {
  itens: AssinaturaAdmin[];
  total: number;
  pagina: number;
  limite: number;
}

export interface FiltroAssinaturasAdmin {
  busca: string;
  situacao: '' | SituacaoAssinaturaAdmin;
  pagina: number;
}