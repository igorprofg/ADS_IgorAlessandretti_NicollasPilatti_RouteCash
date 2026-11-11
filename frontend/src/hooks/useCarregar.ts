import { useCallback, useEffect, useState } from 'react';
import { mensagemDeErro } from '../utilitarios/mensagem-erro';

// Carrega dados de uma função assíncrona quando a tela abre.
// Passe uma função ESTÁVEL (declarada fora do componente, ou com useCallback),
// senão a tela buscaria de novo a cada renderização.
export function useCarregar<T>(buscar: () => Promise<T>) {
  const [dados, setDados] = useState<T | null>(null);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState('');
  const [versao, setVersao] = useState(0);

  useEffect(() => {
    let cancelado = false;
    setCarregando(true);
    setErro('');

    buscar()
      .then((resultado) => {
        if (!cancelado) setDados(resultado);
      })
      .catch((e) => {
        if (!cancelado) setErro(mensagemDeErro(e, 'Não foi possível carregar os dados'));
      })
      .finally(() => {
        if (!cancelado) setCarregando(false);
      });

    return () => {
      cancelado = true;
    };
  }, [buscar, versao]);

  // Busca de novo (ex.: depois de cancelar uma assinatura)
  const recarregar = useCallback(() => setVersao((v) => v + 1), []);

  return { dados, carregando, erro, recarregar };
}