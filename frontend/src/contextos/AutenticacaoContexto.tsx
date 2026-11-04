import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';
import type { ReactNode } from 'react';
import { CHAVE_TOKEN } from '../servicos/api';
import { buscarPerfil, fazerLogin } from '../servicos/autenticacao.servico';
import type { Usuario } from '../tipos/usuario.tipos';

interface AutenticacaoContextoDados {
  usuario: Usuario | null;
  carregando: boolean;
  entrar: (email: string, senha: string) => Promise<void>;
  sair: () => void;
}

const AutenticacaoContexto = createContext<AutenticacaoContextoDados | undefined>(
  undefined,
);

export function AutenticacaoProvedor({ children }: { children: ReactNode }) {
  const [usuario, setUsuario] = useState<Usuario | null>(null);
  // Se já existe token guardado, começa "carregando" até descobrir quem é o usuário
  const [carregando, setCarregando] = useState(() =>
    Boolean(localStorage.getItem(CHAVE_TOKEN)),
  );

  // Ao abrir o site, restaura a sessão a partir do token guardado
  useEffect(() => {
    if (!localStorage.getItem(CHAVE_TOKEN)) return;

    buscarPerfil()
      .then(setUsuario)
      .catch(() => localStorage.removeItem(CHAVE_TOKEN))
      .finally(() => setCarregando(false));
  }, []);

  const entrar = useCallback(async (email: string, senha: string) => {
    const resposta = await fazerLogin(email, senha);
    localStorage.setItem(CHAVE_TOKEN, resposta.access_token);
    setUsuario(resposta.usuario);
  }, []);

  const sair = useCallback(() => {
    localStorage.removeItem(CHAVE_TOKEN);
    setUsuario(null);
  }, []);

  const valor = useMemo(
    () => ({ usuario, carregando, entrar, sair }),
    [usuario, carregando, entrar, sair],
  );

  return (
    <AutenticacaoContexto.Provider value={valor}>
      {children}
    </AutenticacaoContexto.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAutenticacao() {
  const contexto = useContext(AutenticacaoContexto);
  if (!contexto) {
    throw new Error('useAutenticacao deve ser usado dentro de AutenticacaoProvedor');
  }
  return contexto;
}