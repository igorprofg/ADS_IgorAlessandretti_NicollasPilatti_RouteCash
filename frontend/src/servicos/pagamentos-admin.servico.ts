import { api } from './api';
import type { SituacaoPagamento } from '../tipos/assinaturas.tipos';
import type {
  DadosPagamento,
  FiltroPagamentosAdmin,
  PagamentoAdmin,
  PaginaPagamentosAdmin,
} from '../tipos/pagamentos-admin.tipos';

const POR_PAGINA = 20;

// HU53: listar, pesquisar e filtrar por situação
export async function listarPagamentosAdmin(filtro: FiltroPagamentosAdmin) {
  const { data } = await api.get<PaginaPagamentosAdmin>('/admin/pagamentos', {
    params: {
      busca: filtro.busca || undefined,
      situacao: filtro.situacao || undefined,
      pagina: filtro.pagina,
      limite: POR_PAGINA,
    },
  });
  return data;
}

// HU52
export async function registrarPagamento(dados: DadosPagamento) {
  const { data } = await api.post<PagamentoAdmin>('/admin/pagamentos', dados);
  return data;
}

// HU54
export async function atualizarSituacaoPagamento(
  id: string,
  situacao: SituacaoPagamento,
  dataPagamento?: string,
) {
  const { data } = await api.patch<PagamentoAdmin>(`/admin/pagamentos/${id}/situacao`, {
    situacao,
    data_pagamento: situacao === 'PAGO' ? dataPagamento : undefined,
  });
  return data;
}