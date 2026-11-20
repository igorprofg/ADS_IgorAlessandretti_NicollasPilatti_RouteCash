import { Navigate, Route, Routes } from 'react-router-dom';
import RotaPrivada from './RotaPrivada';
import RotaMotorista from './RotaMotorista';
import RotaAdministrador from './RotaAdministrador';
import LayoutPrincipal from '../componentes/layout/LayoutPrincipal';
import Login from '../paginas/autenticacao/Login';
import Cadastro from '../paginas/autenticacao/Cadastro';
import Dashboard from '../paginas/dashboard/Dashboard';
import Planos from '../paginas/planos/Planos';
import DetalhePlano from '../paginas/planos/DetalhePlano';
import Assinatura from '../paginas/assinatura/Assinatura';
import Pagamentos from '../paginas/pagamentos/Pagamentos';
import Assinantes from '../paginas/admin/assinantes/Assinantes';
import DetalheAssinante from '../paginas/admin/assinantes/DetalheAssinante';
import PlanosAdmin from '../paginas/admin/planos/PlanosAdmin';
import FormularioPlano from '../paginas/admin/planos/FormularioPlano';
import AssinaturasAdmin from '../paginas/admin/assinaturas/AssinaturasAdmin';
import DetalheAssinaturaAdmin from '../paginas/admin/assinaturas/DetalheAssinaturaAdmin';
import PagamentosAdmin from '../paginas/admin/pagamentos/PagamentosAdmin';
import FormularioPagamento from '../paginas/admin/pagamentos/FormularioPagamento';

export default function Rotas() {
  return (
    <Routes>
      {/* Públicas */}
      <Route path="/login" element={<Login />} />
      <Route path="/cadastro" element={<Cadastro />} />

      {/* Exigem login e aparecem dentro da moldura (cabeçalho + menu lateral) */}
      <Route element={<RotaPrivada />}>
        <Route element={<LayoutPrincipal />}>
          {/* Motorista */}
          <Route element={<RotaMotorista />}>
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/planos" element={<Planos />} />
            <Route path="/planos/:id" element={<DetalhePlano />} />
            <Route path="/assinatura" element={<Assinatura />} />
            <Route path="/pagamentos" element={<Pagamentos />} />
          </Route>

          {/* Administrador */}
          <Route element={<RotaAdministrador />}>
            <Route path="/admin/assinantes" element={<Assinantes />} />
            <Route path="/admin/assinantes/:id" element={<DetalheAssinante />} />
            <Route path="/admin/planos" element={<PlanosAdmin />} />
            <Route path="/admin/planos/novo" element={<FormularioPlano />} />
            <Route path="/admin/planos/:id/editar" element={<FormularioPlano />} />
            <Route path="/admin/assinaturas" element={<AssinaturasAdmin />} />
            <Route path="/admin/assinaturas/:id" element={<DetalheAssinaturaAdmin />} />
            <Route path="/admin/pagamentos" element={<PagamentosAdmin />} />
            <Route path="/admin/pagamentos/novo" element={<FormularioPagamento />} />
          </Route>
        </Route>
      </Route>

      {/* Qualquer outro endereço cai no dashboard (administrador é redirecionado dali para a área dele) */}
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
}