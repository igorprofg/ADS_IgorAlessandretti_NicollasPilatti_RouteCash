import type { Indicadores } from '../../tipos/indicadores.tipos';
import { formatarMoeda } from '../../utilitarios/formatadores';

interface CartaoResumoProps {
  indicadores: Indicadores;
}

// Card principal (mesmo gradiente verde do resumo da Home do app)
export default function CartaoResumo({ indicadores }: CartaoResumoProps) {
  const negativo = indicadores.lucro_liquido < 0;

  return (
    <section className="cartao-resumo">
      <p className="cartao-resumo-rotulo">Lucro líquido</p>
      <p
        className={`cartao-resumo-valor${negativo ? ' cartao-resumo-valor--negativo' : ''}`}
      >
        {formatarMoeda(indicadores.lucro_liquido)}
      </p>

      <div className="cartao-resumo-linha">
        <div>
          <span className="cartao-resumo-rotulo">Faturamento</span>
          <strong>{formatarMoeda(indicadores.faturamento)}</strong>
        </div>
        <div>
          <span className="cartao-resumo-rotulo">Despesas</span>
          <strong>{formatarMoeda(indicadores.despesas)}</strong>
        </div>
      </div>
    </section>
  );
}