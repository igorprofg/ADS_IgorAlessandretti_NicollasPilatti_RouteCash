// Períodos de cobrança aceitos nos planos e o número de meses de cada um.
// No banco a coluna periodo_cobranca é texto livre (VARCHAR 30); este é o padrão do sistema.
// O RF16 (cadastro de planos pelo administrador) deve validar com esta mesma lista.
export const MESES_POR_PERIODO = {
  MENSAL: 1,
  TRIMESTRAL: 3,
  SEMESTRAL: 6,
  ANUAL: 12,
} as const;

export type PeriodoCobranca = keyof typeof MESES_POR_PERIODO;

export const PERIODOS_COBRANCA = Object.keys(MESES_POR_PERIODO) as PeriodoCobranca[];

// Devolve o número de meses do período, ou null se o texto não for um período conhecido
export function mesesDoPeriodo(periodo: string): number | null {
  const chave = periodo.trim().toUpperCase();
  if (!Object.prototype.hasOwnProperty.call(MESES_POR_PERIODO, chave)) {
    return null;
  }
  return MESES_POR_PERIODO[chave as PeriodoCobranca];
}

// Data de hoje (do servidor) como Date em UTC à meia-noite, própria para colunas DATE
export function hojeComoData(): Date {
  const agora = new Date();
  return new Date(
    Date.UTC(agora.getFullYear(), agora.getMonth(), agora.getDate()),
  );
}

// Soma meses a uma data (UTC). Se o dia não existe no mês de destino, usa o último dia dele:
// 31/01 + 1 mês = 28/02 (ou 29/02 em ano bissexto); 31/10 + 1 mês = 30/11.
export function adicionarMeses(base: Date, meses: number): Date {
  const ano = base.getUTCFullYear();
  const mes = base.getUTCMonth() + meses;
  const dia = base.getUTCDate();
  const ultimoDiaDoMes = new Date(Date.UTC(ano, mes + 1, 0)).getUTCDate();
  return new Date(Date.UTC(ano, mes, Math.min(dia, ultimoDiaDoMes)));
}