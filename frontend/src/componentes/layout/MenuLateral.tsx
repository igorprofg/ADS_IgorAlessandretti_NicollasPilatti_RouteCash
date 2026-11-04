import { NavLink } from 'react-router-dom';
import { useAutenticacao } from '../../contextos/AutenticacaoContexto';
import type { TipoUsuario } from '../../tipos/usuario.tipos';

interface ItemMenu {
  caminho: string;
  rotulo: string;
  apenas?: TipoUsuario; // se informado, só esse tipo de usuário vê o item
}

// Para incluir uma tela no menu, basta acrescentar um item aqui (e a rota em Rotas.tsx).
// Exemplos futuros: { caminho: '/planos', rotulo: 'Planos', apenas: 'ADMINISTRADOR' }
const ITENS: ItemMenu[] = [{ caminho: '/dashboard', rotulo: 'Dashboard' }];

interface MenuLateralProps {
  aberto: boolean; // só faz diferença em telas pequenas (menu vira gaveta)
  aoFechar: () => void;
}

export default function MenuLateral({ aberto, aoFechar }: MenuLateralProps) {
  const { usuario } = useAutenticacao();
  const itens = ITENS.filter(
    (item) => !item.apenas || item.apenas === usuario?.tipo_usuario,
  );

  return (
    <>
      {aberto && <div className="menu-fundo" onClick={aoFechar} />}

      <nav className={`menu-lateral${aberto ? ' menu-lateral--aberto' : ''}`}>
        <ul>
          {itens.map((item) => (
            <li key={item.caminho}>
              <NavLink
                to={item.caminho}
                onClick={aoFechar}
                className={({ isActive }) =>
                  `menu-item${isActive ? ' menu-item--ativo' : ''}`
                }
              >
                {item.rotulo}
              </NavLink>
            </li>
          ))}
        </ul>
      </nav>
    </>
  );
}