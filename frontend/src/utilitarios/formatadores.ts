export const SEM_VALOR = '—';

const formatoMoeda = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
});

const formatoKm = new Intl.NumberFormat('pt-BR', {
  minimumFractionDigits: 0,
  maximumFractionDigits: 1,
});

const formatoCompacto = new Intl.NumberFormat('pt-BR', {
  notation: 'compact',
  maximumFractionDigits: 1,
});

// null (indicador sem dados no período) vira "—"
export function formatarMoeda(valor: number | null) {
  return valor === null ? SEM_VALOR : formatoMoeda.format(valor);
}

export function formatarKm(km: number) {
  return `${formatoKm.format(km)} km`;
}

// 6.5 -> "6h30"
export function formatarHoras(horas: number) {
  const minutos = Math.round(horas * 60);
  const h = Math.floor(minutos / 60);
  const m = minutos % 60;
  return `${h}h${String(m).padStart(2, '0')}`;
}

// Números curtos para o eixo dos gráficos (ex.: 1,2 mil)
export function formatarEixo(valor: number) {
  return formatoCompacto.format(valor);
}

// '2026-10-20' -> '20/10'  (sem usar Date, para não sofrer com fuso horário)
export function formatarDiaMes(dia: string) {
  const [, mes, d] = dia.split('-');
  return `${d}/${mes}`;
}

// '2026-10-20' -> '20/10/2026'
export function formatarData(dia: string) {
  const [ano, mes, d] = dia.split('-');
  return `${d}/${mes}/${ano}`;
}