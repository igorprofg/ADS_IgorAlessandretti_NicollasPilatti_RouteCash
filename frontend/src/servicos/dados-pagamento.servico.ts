import { api } from './api';
import type {
  DadosPagamentoUsuario,
  SalvarDadosPagamento,
} from '../tipos/dados-pagamento.tipos';

export async function buscarDadosPagamento() {
  const { data } = await api.get<DadosPagamentoUsuario>('/usuarios/me/dados-pagamento');
  return data;
}

export async function salvarDadosPagamento(dados: SalvarDadosPagamento) {
  const { data } = await api.patch<DadosPagamentoUsuario>('/usuarios/me/dados-pagamento', dados);
  return data;
}