import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import Cabecalho from './Cabecalho';
import MenuLateral from './MenuLateral';
import './layout.css';

// Moldura das telas internas: cabeçalho no topo, menu à esquerda e o conteúdo da rota ao lado
export default function LayoutPrincipal() {
  const [menuAberto, setMenuAberto] = useState(false);

  return (
    <div className="layout">
      <Cabecalho aoAlternarMenu={() => setMenuAberto((aberto) => !aberto)} />

      <div className="layout-corpo">
        <MenuLateral aberto={menuAberto} aoFechar={() => setMenuAberto(false)} />
        <main className="layout-conteudo">
          <Outlet />
        </main>
      </div>
    </div>
  );
}