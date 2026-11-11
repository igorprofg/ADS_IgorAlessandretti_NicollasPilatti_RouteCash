import { useCarregar } from '../../hooks/useCarregar';
import { listarPlanos } from '../../servicos/planos.servico';
import CartaoPlano from '../../componentes/planos/CartaoPlano';
import '../../estilos/assinaturas.css';

// RF12 – Visualizar Planos. Tudo vem do banco (nada fixo na tela).
export default function Planos() {
  const { dados: planos, carregando, erro } = useCarregar(listarPlanos);

  return (
    <section className="pagina">
      <div>
        <h1>Planos</h1>
        <p className="texto-secundario">Conheça os planos disponíveis do RouteCash.</p>
      </div>

      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}

      {carregando && !planos && <p className="texto-secundario">Carregando...</p>}

      {planos && planos.length === 0 && (
        <p className="texto-secundario">Nenhum plano disponível no momento.</p>
      )}

      {planos && planos.length > 0 && (
        <div className="grade-planos">
          {planos.map((plano) => (
            <CartaoPlano key={plano.id_plano} plano={plano} />
          ))}
        </div>
      )}
    </section>
  );
}