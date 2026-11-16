import { api } from './api';
import type {
  AssinanteDetalhe,
  FiltroAssinantes,
  PaginaAssinantes,
} from '../tipos/admin.tipos';

const POR_PAGINA = 20;

// HU41: listar e pesquisar por nome e/ou e-mail
export async function listarAssinantes(filtro: FiltroAssinantes) {
  const { data } = await api.get<PaginaAssinantes>('/admin/assinantes', {
    params: {
      nome: filtro.nome || undefined,
      email: filtro.email || undefined,
      pagina: filtro.pagina,
      limite: POR_PAGINA,
    },
  });
  return data;
}

export async function buscarAssinante(id: string) {
  const { data } = await api.get<AssinanteDetalhe>(`/admin/assinantes/${id}`);
  return data;
}

// HU42
export async function ativarAssinante(id: string) {
  const { data } = await api.patch<AssinanteDetalhe>(`/admin/assinantes/${id}/ativar`);
  return data;
}

// HU43
export async function suspenderAssinante(id: string) {
  const { data } = await api.patch<AssinanteDetalhe>(`/admin/assinantes/${id}/suspender`);
  return data;
}

// HU44
export async function bloquearAssinante(id: string) {
  const { data } = await api.patch<AssinanteDetalhe>(`/admin/assinantes/${id}/bloquear`);
  return data;
}