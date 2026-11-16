import { api } from './api';
import type { DadosPlano, PlanoAdmin } from '../tipos/planos-admin.tipos';

// Consultar planos (todos, inclusive inativos)
export async function listarPlanosAdmin() {
  const { data } = await api.get<PlanoAdmin[]>('/admin/planos');
  return data;
}

export async function buscarPlanoAdmin(id: string) {
  const { data } = await api.get<PlanoAdmin>(`/admin/planos/${id}`);
  return data;
}

// HU45
export async function criarPlano(dados: DadosPlano) {
  const { data } = await api.post<PlanoAdmin>('/admin/planos', dados);
  return data;
}

// HU46
export async function atualizarPlano(id: string, dados: DadosPlano) {
  const { data } = await api.patch<PlanoAdmin>(`/admin/planos/${id}`, dados);
  return data;
}

// HU47
export async function ativarPlano(id: string) {
  const { data } = await api.patch<PlanoAdmin>(`/admin/planos/${id}/ativar`);
  return data;
}

export async function inativarPlano(id: string) {
  const { data } = await api.patch<PlanoAdmin>(`/admin/planos/${id}/inativar`);
  return data;
}