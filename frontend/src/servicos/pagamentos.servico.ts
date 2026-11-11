import { api } from './api';
import type { Pagamento } from '../tipos/assinaturas.tipos';

// RF14: histórico próprio, do mais recente para o mais antigo
export async function listarPagamentos() {
  const { data } = await api.get<Pagamento[]>('/pagamentos');
  return data;
}