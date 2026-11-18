import type {
  OrigemAssinatura,
  SituacaoAssinaturaAdmin,
} from '../tipos/assinaturas-admin.tipos';
import { formatarData, SEM_VALOR } from './formatadores';
import type { DadosEtiqueta } from './rotulos';

export const OPCOES_SITUACAO: { valor: SituacaoAssinaturaAdmin; rotulo: string }[] = [
  { valor: 'PENDENTE', rotulo: 'Aguardando pagamento' },
  { valor: 'ATIVA', rotulo: 'Ativa' },
  { valor: 'SUSPENSA', rotulo: 'Suspensa' },
  { valor: 'CANCELADA', rotulo: 'Cancelada' },
];

export function etiquetaSituacao(situacao: SituacaoAssinaturaAdmin): DadosEtiqueta {
  switch (situacao) {
    case 'ATIVA':
      return { texto: 'Ativa', tipo: 'positivo' };
    case 'PENDENTE':
      return { texto: 'Aguardando pagamento', tipo: 'neutro' };
    case 'SUSPENSA':
      return { texto: 'Suspensa', tipo: 'neutro' };
    default:
      return { texto: 'Cancelada', tipo: 'negativo' };
  }
}

export function rotuloOrigem(origem: OrigemAssinatura) {
  return origem === 'ASAAS' ? 'Pagamento online (Asaas)' : 'Liberação manual';
}

// Datas nulas (assinatura pendente) viram "—"
export function dataOuTraco(dia: string | null) {
  return dia ? formatarData(dia) : SEM_VALOR;
}