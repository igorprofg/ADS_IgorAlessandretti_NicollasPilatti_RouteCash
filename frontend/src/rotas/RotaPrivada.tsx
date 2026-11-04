import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAutenticacao } from '../contextos/AutenticacaoContexto';

// Protege as telas internas: sem login, manda para /login
// (e guarda de onde veio, para voltar depois de entrar)
export default function RotaPrivada() {
  const { usuario, carregando } = useAutenticacao();
  const local = useLocation();

  if (carregando) {
    return (
      <main className="pagina-centralizada">
        <p className="texto-secundario">Carregando...</p>
      </main>
    );
  }

  if (!usuario) {
    return <Navigate to="/login" replace state={{ de: local.pathname }} />;
  }

  return <Outlet />;
}