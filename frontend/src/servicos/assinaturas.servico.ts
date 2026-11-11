import { isAxiosError } from 'axios';
import { api } from './api';
import type { Assinatura } from '../tipos/assinaturas.tipos';

// HU37
export async function contratarPlano(idPlano: string) {
  const { data } = await api.post<Assinatura>('/assinaturas', {
    id_plano: idPlano,
  });
  return data;
}

// HU38: o backend responde 404 quando o usuário não tem assinatura; aqui isso vira null
export async function buscarAssinaturaAtual(): Promise<Assinatura | null> {
  try {
    const { data } = await api.get<Assinatura>('/assinaturas/atual');
    return data;
  } catch (erro) {
    if (isAxiosError(erro) && erro.response?.status === 404) {
      return null;
    }
    throw erro;
  }
}

// Histórico próprio (inclui as canceladas)
export async function listarAssinaturas() {
  const { data } = await api.get<Assinatura[]>('/assinaturas');
  return data;
}

// HU39
export async function cancelarAssinaturaAtual() {
  const { data } = await api.patch<Assinatura>('/assinaturas/atual/cancelar');
  return data;
}