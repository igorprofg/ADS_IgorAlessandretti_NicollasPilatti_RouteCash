import { useState } from 'react';
import { useAutenticacao } from '../../contextos/AutenticacaoContexto';
import { alternarTema, temaAtual, type Tema } from '../../utilitarios/tema';

interface CabecalhoProps {
  aoAlternarMenu: () => void;
}

export default function Cabecalho({ aoAlternarMenu }: CabecalhoProps) {
  const { usuario, sair } = useAutenticacao();
  const [tema, setTema] = useState<Tema>(temaAtual);

  return (
    <header className="cabecalho">
      <button
        className="botao-icone botao-menu"
        onClick={aoAlternarMenu}
        aria-label="Abrir ou fechar o menu"
      >
        ☰
      </button>

      <span className="cabecalho-marca">RouteCash</span>

      <div className="cabecalho-acoes">
        <button
          className="botao-icone"
          onClick={() => setTema(alternarTema())}
          aria-label={tema === 'escuro' ? 'Usar tema claro' : 'Usar tema escuro'}
        >
          {tema === 'escuro' ? '☀' : '☾'}
        </button>
        <span className="cabecalho-usuario">{usuario?.nome}</span>
        <button className="botao-secundario" onClick={sair}>
          Sair
        </button>
      </div>
    </header>
  );
}