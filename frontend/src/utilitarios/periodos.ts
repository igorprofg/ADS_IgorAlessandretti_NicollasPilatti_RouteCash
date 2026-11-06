import type { Periodo } from '../tipos/indicadores.tipos';

export type PresetPeriodo = 'hoje' | '7dias' | 'mes' | 'livre';

export const LIMITE_DIAS = 366; // mesmo limite do backend (GET /indicadores/serie)

const MS_DIA = 24 * 60 * 60 * 1000;

// Data local (do navegador) no formato AAAA-MM-DD.
// Não usa toISOString() porque ele converte para UTC e pode virar o dia.
function paraTexto(data: Date) {
  const aaaa = data.getFullYear();
  const mm = String(data.getMonth() + 1).padStart(2, '0');
  const dd = String(data.getDate()).padStart(2, '0');
  return `${aaaa}-${mm}-${dd}`;
}

export function periodoDoPreset(preset: Exclude<PresetPeriodo, 'livre'>): Periodo {
  const hoje = new Date();
  const fim = paraTexto(hoje);

  if (preset === 'hoje') {
    return { inicio: fim, fim };
  }

  if (preset === '7dias') {
    const inicio = new Date(hoje);
    inicio.setDate(hoje.getDate() - 6); // hoje + 6 dias anteriores
    return { inicio: paraTexto(inicio), fim };
  }

  // mês: do dia 1 até hoje
  const primeiro = new Date(hoje.getFullYear(), hoje.getMonth(), 1);
  return { inicio: paraTexto(primeiro), fim };
}

// Devolve a mensagem de erro (ou '' se o período é válido). Mesmas regras da HU30.
export function validarPeriodo(periodo: Periodo) {
  if (!periodo.inicio || !periodo.fim) {
    return 'Informe a data inicial e a data final';
  }
  if (periodo.fim < periodo.inicio) {
    return 'A data final não pode ser anterior à data inicial';
  }
  const dias =
    (Date.parse(`${periodo.fim}T00:00:00Z`) -
      Date.parse(`${periodo.inicio}T00:00:00Z`)) /
      MS_DIA +
    1;
  if (dias > LIMITE_DIAS) {
    return `O período máximo é de ${LIMITE_DIAS} dias`;
  }
  return '';
}