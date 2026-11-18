import { api } from './api';
import type {
  AssinaturaAdminDetalhe,
  FiltroAssinaturasAdmin,
  PaginaAssinaturasAdmin,
} from '../tipos/assinaturas-admin.tipos';

const POR_PAGINA = 20;

// Listar, pesquisar e filtrar por situação
export async function listarAssinaturasAdmin(filtro: FiltroAssinaturasAdmin) {
  const { data } = await api.get<PaginaAssinaturasAdmin>('/admin/assinaturas', {
    params: {
      busca: filtro.busca || undefined,
      situacao: filtro.situacao || undefined,
      pagina: filtro.pagina,
      limite: POR_PAGINA,
    },
  });
  return data;
}

export async function buscarAssinaturaAdmin(id: string) {
  const { data } = await api.get<AssinaturaAdminDetalhe>(`/admin/assinaturas/${id}`);
  return data;
}

export async function suspenderAssinatura(id: string) {
  const { data } = await api.patch<AssinaturaAdminDetalhe>(`/admin/assinaturas/${id}/suspender`);
  return data;
}

export async function reativarAssinatura(id: string) {
  const { data } = await api.patch<AssinaturaAdminDetalhe>(`/admin/assinaturas/${id}/reativar`);
  return data;
}

export async function cancelarAssinaturaAdmin(id: string) {
  const { data } = await api.patch<AssinaturaAdminDetalhe>(`/admin/assinaturas/${id}/cancelar`);
  return data;
}