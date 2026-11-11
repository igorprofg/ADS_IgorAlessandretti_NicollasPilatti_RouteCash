import { useEffect } from 'react';
import type { ReactNode } from 'react';
import './comum.css';

interface ModalConfirmacaoProps {
  titulo: string;
  children: ReactNode;
  textoConfirmar: string;
  perigo?: boolean; // botão de confirmar em vermelho (ações destrutivas)
  processando?: boolean;
  erro?: string;
  aoConfirmar: () => void;
  aoCancelar: () => void;
}

export default function ModalConfirmacao({
  titulo,
  children,
  textoConfirmar,
  perigo = false,
  processando = false,
  erro = '',
  aoConfirmar,
  aoCancelar,
}: ModalConfirmacaoProps) {
  // Esc fecha a janela (a menos que esteja processando)
  useEffect(() => {
    function aoTeclar(evento: KeyboardEvent) {
      if (evento.key === 'Escape' && !processando) aoCancelar();
    }
    window.addEventListener('keydown', aoTeclar);
    return () => window.removeEventListener('keydown', aoTeclar);
  }, [aoCancelar, processando]);

  return (
    <div className="modal-fundo" onClick={processando ? undefined : aoCancelar}>
      <div
        className="card modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-titulo"
        onClick={(evento) => evento.stopPropagation()}
      >
        <h2 id="modal-titulo">{titulo}</h2>
        {children}

        {erro && (
          <p className="mensagem-erro" role="alert">
            {erro}
          </p>
        )}

        <div className="modal-acoes">
          <button
            type="button"
            className="botao-secundario"
            onClick={aoCancelar}
            disabled={processando}
          >
            Voltar
          </button>
          <button
            type="button"
            className={`botao${perigo ? ' botao-perigo' : ''}`}
            onClick={aoConfirmar}
            disabled={processando}
          >
            {processando ? 'Aguarde...' : textoConfirmar}
          </button>
        </div>
      </div>
    </div>
  );
}