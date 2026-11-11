import { Link } from 'react-router-dom';
import type { Plano } from '../../tipos/assinaturas.tipos';
import { formatarMoeda } from '../../utilitarios/formatadores';
import { listarBeneficios, sufixoPeriodo } from '../../utilitarios/rotulos';
import Etiqueta from '../comum/Etiqueta';
import '../../estilos/assinaturas.css';

interface CartaoPlanoProps {
  plano: Plano;
}

export default function CartaoPlano({ plano }: CartaoPlanoProps) {
  const beneficios = listarBeneficios(plano.beneficios);

  return (
    <article
      className={`card cartao-plano${plano.contratado ? ' cartao-plano--contratado' : ''}`}
    >
      <div className="cartao-plano-topo">
        <h3>{plano.nome}</h3>
        {plano.contratado && <Etiqueta texto="Seu plano" tipo="positivo" />}
      </div>

      <p className="cartao-plano-preco">
        {formatarMoeda(plano.valor)} <small>/ {sufixoPeriodo(plano.periodo_cobranca)}</small>
      </p>

      <ul className="lista-beneficios">
        {beneficios.slice(0, 4).map((beneficio) => (
          <li key={beneficio}>{beneficio}</li>
        ))}
      </ul>

      <Link className="botao-secundario link-botao" to={`/planos/${plano.id_plano}`}>
        Ver detalhes
      </Link>
    </article>
  );
}