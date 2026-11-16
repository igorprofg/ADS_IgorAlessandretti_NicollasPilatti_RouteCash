import { Navigate, Outlet } from 'react-router-dom';
import { useAutenticacao } from '../contextos/AutenticacaoContexto';

// Telas do motorista (dashboard, planos, assinatura, pagamentos).
// Quem é administrador vai para a área administrativa.
export default function RotaMotorista() {
  const { usuario } = useAutenticacao();

  if (usuario?.tipo_usuario === 'ADMINISTRADOR') {
    return <Navigate to="/admin/assinantes" replace />;
  }
  return <Outlet />;
}