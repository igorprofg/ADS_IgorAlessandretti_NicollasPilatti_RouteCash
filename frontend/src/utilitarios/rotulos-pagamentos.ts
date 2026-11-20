import type { SituacaoPagamento } from '../tipos/assinaturas.tipos';

export const OPCOES_SITUACAO_PAGAMENTO: { valor: SituacaoPagamento; rotulo: string }[] = [
  { valor: 'PENDENTE', rotulo: 'Pendente' },
  { valor: 'PAGO', rotulo: 'Pago' },
  { valor: 'VENCIDO', rotulo: 'Vencido' },
  { valor: 'CANCELADO', rotulo: 'Cancelado' },
];