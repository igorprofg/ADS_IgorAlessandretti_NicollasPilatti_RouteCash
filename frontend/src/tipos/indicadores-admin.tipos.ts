export interface ResumoPagamentos {
  quantidade: number;
  valor: number;
}

// Resposta de GET /admin/indicadores
export interface IndicadoresAdmin {
  periodo: { inicio: string; fim: string } | null; // null = todo o período
  usuarios: { total: number };
  assinaturas: {
    total: number;
    pendentes: number;
    ativas: number;
    suspensas: number;
    canceladas: number;
  };
  pagamentos: {
    pendentes: ResumoPagamentos;
    vencidos: ResumoPagamentos;
    pagos: ResumoPagamentos;
    cancelados: ResumoPagamentos;
  };
  receita_registrada: number;
  receita_mensal: { mes: string; receita: number }[]; // mes = AAAA-MM
}