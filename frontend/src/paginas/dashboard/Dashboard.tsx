import { useAutenticacao } from '../../contextos/AutenticacaoContexto';

// Página provisória dentro do layout. Será substituída pelo dashboard do RF10
// (resumo financeiro, indicadores e gráficos com Recharts).
export default function Dashboard() {
  const { usuario } = useAutenticacao();

  return (
    <section>
      <h1>Olá, {usuario?.nome}!</h1>
      <p className="texto-secundario">
        Aqui entra o dashboard financeiro (RF10).
      </p>

      <div className="card">
        <p className="texto-secundario">Resumo financeiro</p>
        <p>
          <span className="receita">+ R$ 150,00</span>{' '}
          <span className="despesa">- R$ 35,00</span>
        </p>
      </div>
    </section>
  );
}