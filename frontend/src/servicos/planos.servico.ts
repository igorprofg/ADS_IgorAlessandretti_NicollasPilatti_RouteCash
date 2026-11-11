import { api } from './api';
import type { Plano } from '../tipos/assinaturas.tipos';

// RF12: só planos ativos, com o plano contratado identificado
export async function listarPlanos() {
  const { data } = await api.get<Plano[]>('/planos');
  return data;
}

export async function buscarPlano(id: string) {
  const { data } = await api.get<Plano>(`/planos/${id}`);
  return data;
}