export type Tema = 'claro' | 'escuro';

const CHAVE_TEMA = 'routecash_tema';

function temaDoSistema(): Tema {
  return window.matchMedia('(prefers-color-scheme: dark)').matches
    ? 'escuro'
    : 'claro';
}

export function temaAtual(): Tema {
  return document.documentElement.dataset.tema === 'escuro' ? 'escuro' : 'claro';
}

// Chamar uma vez ao iniciar o app (main.tsx): usa a escolha salva
// ou, se não houver, o tema do sistema (igual ao app mobile)
export function aplicarTemaInicial() {
  const salvo = localStorage.getItem(CHAVE_TEMA);
  const tema: Tema = salvo === 'claro' || salvo === 'escuro' ? salvo : temaDoSistema();
  document.documentElement.dataset.tema = tema;
}

// Troca claro <-> escuro e guarda a escolha
export function alternarTema(): Tema {
  const novo: Tema = temaAtual() === 'escuro' ? 'claro' : 'escuro';
  document.documentElement.dataset.tema = novo;
  localStorage.setItem(CHAVE_TEMA, novo);
  return novo;
}