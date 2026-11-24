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

    // O AsaasService devolve { mensagem, resposta: { errors: [{ description }] } }
    const outra = erro.response.data?.mensagem;
    const detalhes = erro.response.data?.resposta?.errors;
    if (Array.isArray(detalhes) && detalhes.length > 0) {
      return detalhes
        .map((d: { description?: string }) => d.description)
        .filter(Boolean)
        .join('. ');
    }
    if (typeof outra === 'string') return outra;
  }
  return padrao;
}