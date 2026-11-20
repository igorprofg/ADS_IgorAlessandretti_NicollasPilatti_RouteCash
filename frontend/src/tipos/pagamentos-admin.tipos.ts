import type { SituacaoPagamento } from './assinaturas.tipos';
import type { SituacaoAssinaturaAdmin } from './assinaturas-admin.tipos';

// Item de GET /admin/pagamentos
export interface PagamentoAdmin {
  id_pagamento: string;
  id_assinatura: string;
  valor: number;
  data_vencimento: string; // AAAA-MM-DD
  data_pagamento: string | null; // AAAA-MM-DD
  situacao: SituacaoPagamento;
  em_atraso: boolean; // pendente com o vencimento já passado (calculado)
  origem: 'MANUAL' | 'ASAAS'; // ASAAS = criado pelo Webhook: não se altera manualmente
  assinatura_situacao: SituacaoAssinaturaAdmin;
  usuario: { id_usuario: string; nome: string; email: string };
  plano_nome: string;
}

export interface PaginaPagamentosAdmin {
  itens: PagamentoAdmin[];
  total: number;
  pagina: number;
  limite: number;
}

export interface FiltroPagamentosAdmin {
  busca: string;
  situacao: '' | SituacaoPagamento;
  pagina: number;
}

// Corpo de POST /admin/pagamentos
export interface DadosPagamento {
  id_assinatura: string;
  valor: number;
  data_vencimento: string;
  situacao: SituacaoPagamento;
  data_pagamento?: string;
}