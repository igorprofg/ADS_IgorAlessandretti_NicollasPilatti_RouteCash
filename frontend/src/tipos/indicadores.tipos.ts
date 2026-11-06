// 'AAAA-MM-DD'
export interface Periodo {
  inicio: string;
  fim: string;
}

// Resposta de GET /indicadores
export interface Indicadores {
  periodo: Periodo;
  faturamento: number;
  despesas: number;
  lucro_liquido: number;
  horas_trabalhadas: number;
  km_rodados: number;
  ganho_por_hora: number | null; // null = sem horas no período
  ganho_por_km: number | null; // null = sem km no período
  custo_por_km: number | null; // null = sem km no período
}

export interface DiaSerie {
  data: string; // 'AAAA-MM-DD'
  faturamento: number;
  despesas: number;
  lucro_liquido: number;
  lucro_acumulado: number;
}

interface Valores {
  faturamento: number;
  despesas: number;
  lucro_liquido: number;
}

// Resposta de GET /indicadores/serie
export interface SerieIndicadores {
  periodo: Periodo;
  total_dias: number;
  totais: Valores;
  medias_diarias: Valores;
  dias: DiaSerie[];
}