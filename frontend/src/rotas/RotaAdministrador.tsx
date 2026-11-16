import { Navigate, Outlet } from 'react-router-dom';
import { useAutenticacao } from '../contextos/AutenticacaoContexto';

// Telas administrativas. Quem não é administrador volta para o dashboard.
// (O backend também barra com 403: esta rota só evita mostrar telas que não servem.)
export default function RotaAdministrador() {
  const { usuario } = useAutenticacao();

  if (usuario?.tipo_usuario !== 'ADMINISTRADOR') {
    return <Navigate to="/dashboard" replace />;
  }
  return <Outlet />;
}