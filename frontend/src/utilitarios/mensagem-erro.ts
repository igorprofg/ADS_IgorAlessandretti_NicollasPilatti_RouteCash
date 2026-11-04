import { isAxiosError } from 'axios';

// Converte o erro de uma chamada à API em um texto para mostrar ao usuário.
// O backend devolve { message: "texto" } ou { message: ["texto 1", "texto 2"] } (validações).
export function mensagemDeErro(erro: unknown, padrao: string): string {
  if (isAxiosError(erro)) {
    if (!erro.response) {
      return 'Não foi possível conectar ao servidor. Verifique sua conexão.';
    }
    const mensagem = erro.response.data?.message;
    if (Array.isArray(mensagem)) return mensagem.join('. ');
    if (typeof mensagem === 'string') return mensagem;
  }
  return padrao;
}