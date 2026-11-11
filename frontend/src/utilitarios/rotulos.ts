import type {
  SituacaoAssinatura,
  SituacaoPagamento,
} from '../tipos/assinaturas.tipos';

export type TipoEtiqueta = 'positivo' | 'negativo' | 'neutro';

export interface DadosEtiqueta {
  texto: string;
  tipo: TipoEtiqueta;
}

const PERIODOS: Record<string, string> = {
  MENSAL: 'Mensal',
  TRIMESTRAL: 'Trimestral',
  SEMESTRAL: 'Semestral',
  ANUAL: 'Anual',
};

const SUFIXOS: Record<string, string> = {
  MENSAL: 'mês',
  TRIMESTRAL: 'trimestre',
  SEMESTRAL: 'semestre',
  ANUAL: 'ano',
};

export function rotuloPeriodo(periodo: string) {
  return PERIODOS[periodo.trim().toUpperCase()] ?? periodo;
}

// "R$ 19,90 / mês"
export function sufixoPeriodo(periodo: string) {
  return SUFIXOS[periodo.trim().toUpperCase()] ?? periodo;
}

// Os benefícios vêm do banco como texto, um por linha
export function listarBeneficios(texto: string) {
  return texto
    .split('\n')
    .map((linha) => linha.trim())
    .filter(Boolean);
}

export function etiquetaAssinatura(situacao: SituacaoAssinatura): DadosEtiqueta {
  switch (situacao) {
    case 'ATIVA':
      return { texto: 'Ativa', tipo: 'positivo' };
    case 'SUSPENSA':
      return { texto: 'Suspensa', tipo: 'neutro' };
    default:
      return { texto: 'Cancelada', tipo: 'negativo' };
  }
}

export function etiquetaPagamento(situacao: SituacaoPagamento): DadosEtiqueta {
  switch (situacao) {
    case 'PAGO':
      return { texto: 'Pago', tipo: 'positivo' };
    case 'VENCIDO':
      return { texto: 'Vencido', tipo: 'negativo' };
    default:
      return { texto: 'Pendente', tipo: 'neutro' };
  }
}