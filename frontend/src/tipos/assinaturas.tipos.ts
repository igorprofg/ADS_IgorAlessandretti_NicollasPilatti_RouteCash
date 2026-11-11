// Resposta de GET /planos e GET /planos/:id
export interface Plano {
  id_plano: string;
  nome: string;
  valor: number;
  periodo_cobranca: string; // MENSAL, TRIMESTRAL, SEMESTRAL ou ANUAL
  beneficios: string; // um benefício por linha
  ativo: boolean;
  contratado: boolean; // é o plano da assinatura atual do usuário
  disponivel_para_contratacao: boolean;
}

export interface PlanoResumo {
  id_plano: string;
  nome: string;
  valor: number;
  periodo_cobranca: string;
  beneficios: string;
}

export type SituacaoAssinatura = 'ATIVA' | 'SUSPENSA' | 'CANCELADA';

// Resposta de /assinaturas
export interface Assinatura {
  id_assinatura: string;
  situacao: SituacaoAssinatura;
  data_inicio: string; // AAAA-MM-DD
  data_vencimento: string; // AAAA-MM-DD
  data_cancelamento: string | null; // data e hora ISO
  vencida: boolean; // calculado no backend: o vencimento já passou
  plano: PlanoResumo;
}

export type SituacaoPagamento = 'PAGO' | 'PENDENTE' | 'VENCIDO';

// Resposta de GET /pagamentos
export interface Pagamento {
  id_pagamento: string;
  id_assinatura: string;
  plano_nome: string;
  valor: number;
  data_vencimento: string; // AAAA-MM-DD
  data_pagamento: string | null; // AAAA-MM-DD
  situacao: SituacaoPagamento;
}