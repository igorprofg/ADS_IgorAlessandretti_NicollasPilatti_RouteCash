// Resposta de /admin/planos
export interface PlanoAdmin {
  id_plano: string;
  nome: string;
  valor: number;
  periodo_cobranca: string;
  beneficios: string; // um por linha
  ativo: boolean;
  data_cadastro: string;
  data_atualizacao: string;
  total_assinaturas: number;
  assinaturas_em_aberto: number;
}

// Corpo de POST e PATCH
export interface DadosPlano {
  nome: string;
  valor: number;
  periodo_cobranca: string;
  beneficios: string;
}