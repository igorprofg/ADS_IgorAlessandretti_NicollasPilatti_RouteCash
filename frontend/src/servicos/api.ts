import axios from 'axios';

export const CHAVE_TOKEN = 'routecash_token';

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL ?? 'http://localhost:3000',
});

// Envia o token JWT em toda requisição
api.interceptors.request.use((config) => {
  const token = localStorage.getItem(CHAVE_TOKEN);
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Token expirado ou inválido: limpa a sessão e volta pro login
// (o próprio login com senha errada também retorna 401, por isso é ignorado aqui)
api.interceptors.response.use(
  (resposta) => resposta,
  (erro) => {
    const ehLogin = erro.config?.url?.includes('/autenticacao/login');
    if (erro.response?.status === 401 && !ehLogin) {
      localStorage.removeItem(CHAVE_TOKEN);
      window.location.href = '/login';
    }
    return Promise.reject(erro);
  },
);