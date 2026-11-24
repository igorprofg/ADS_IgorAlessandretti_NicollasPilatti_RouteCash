import { api } from './api';
import type { ResultadoCheckout } from '../tipos/dados-pagamento.tipos';

// Cria (ou reaproveita) o checkout do Asaas para o plano e devolve a URL da página de pagamento
export async function iniciarCheckout(idPlano: string) {
  const { data } = await api.post<ResultadoCheckout>('/assinaturas/asaas', {
    id_plano: idPlano,
  });
  return data;
}