import { api } from './api';
import type {
  CadastroDados,
  LoginResposta,
  Usuario,
} from '../tipos/usuario.tipos';

// RF02: login
export async function fazerLogin(email: string, senha: string) {
  const { data } = await api.post<LoginResposta>('/autenticacao/login', {
    email,
    senha,
  });
  return data;
}

// RF01: cadastro de usuário (motorista)
export async function cadastrarUsuario(dados: CadastroDados) {
  const { data } = await api.post<Usuario>('/usuarios', dados);
  return data;
}

// Usuário logado (usado para restaurar a sessão ao abrir o site)
export async function buscarPerfil() {
  const { data } = await api.get<Usuario>('/usuarios/me');
  return data;
}