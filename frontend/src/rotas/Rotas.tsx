import { Navigate, Route, Routes } from 'react-router-dom';
import RotaPrivada from './RotaPrivada';
import LayoutPrincipal from '../componentes/layout/LayoutPrincipal';
import Login from '../paginas/autenticacao/Login';
import Cadastro from '../paginas/autenticacao/Cadastro';
import Dashboard from '../paginas/dashboard/Dashboard';
import Planos from '../paginas/planos/Planos';
import DetalhePlano from '../paginas/planos/DetalhePlano';
import Assinatura from '../paginas/assinatura/Assinatura';
import Pagamentos from '../paginas/pagamentos/Pagamentos';

export default function Rotas() {
  return (
    <Routes>
      {/* Públicas */}
      <Route path="/login" element={<Login />} />
      <Route path="/cadastro" element={<Cadastro />} />

      {/* Exigem login e aparecem dentro da moldura (cabeçalho + menu lateral) */}
      <Route element={<RotaPrivada />}>
        <Route element={<LayoutPrincipal />}>
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/planos" element={<Planos />} />
          <Route path="/planos/:id" element={<DetalhePlano />} />
          <Route path="/assinatura" element={<Assinatura />} />
          <Route path="/pagamentos" element={<Pagamentos />} />
        </Route>
      </Route>

      {/* Qualquer outro endereço cai no dashboard (que pede login se for preciso) */}
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
}