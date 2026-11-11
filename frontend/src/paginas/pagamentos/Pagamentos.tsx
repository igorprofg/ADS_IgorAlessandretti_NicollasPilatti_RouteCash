import { Link } from 'react-router-dom';
import Etiqueta from '../../componentes/comum/Etiqueta';
import { useCarregar } from '../../hooks/useCarregar';
import { listarPagamentos } from '../../servicos/pagamentos.servico';
import {
  formatarData,
  formatarMoeda,
  SEM_VALOR,
} from '../../utilitarios/formatadores';
import { etiquetaPagamento } from '../../utilitarios/rotulos';
import '../../componentes/comum/comum.css';
import '../../estilos/assinaturas.css';

// RF14 – Consultar Pagamentos (HU40). Os pagamentos são lançados pelo administrador (RF18).
export default function Pagamentos() {
  const { dados: pagamentos, carregando, erro } = useCarregar(listarPagamentos);

  return (
    <section className="pagina">
      <div>
        <h1>Pagamentos</h1>
        <p className="texto-secundario">Histórico dos pagamentos da sua assinatura.</p>
      </div>

      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}

      {carregando && !pagamentos && <p className="texto-secundario">Carregando...</p>}

      {pagamentos && pagamentos.length === 0 && (
        <div className="card estado-vazio">
          <p className="texto-secundario">
            Nenhum pagamento registrado até agora. Os pagamentos são lançados pela
            administração do RouteCash.
          </p>
          <Link to="/assinatura" className="botao-secundario link-botao">
            Ver minha assinatura
          </Link>
        </div>
      )}

      {pagamentos && pagamentos.length > 0 && (
        <div className="card">
          <div className="tabela-container">
            <table className="tabela">
              <thead>
                <tr>
                  <th>Vencimento</th>
                  <th>Pago em</th>
                  <th>Plano</th>
                  <th>Valor</th>
                  <th>Situação</th>
                </tr>
              </thead>
              <tbody>
                {pagamentos.map((pagamento, indice) => (
                  <tr
                    key={pagamento.id_pagamento}
                    className={indice === 0 ? 'linha-destaque' : undefined}
                  >
                    <td>
                      {formatarData(pagamento.data_vencimento)}{' '}
                      {indice === 0 && <Etiqueta texto="Mais recente" tipo="neutro" />}
                    </td>
                    <td>
                      {pagamento.data_pagamento
                        ? formatarData(pagamento.data_pagamento)
                        : SEM_VALOR}
                    </td>
                    <td>{pagamento.plano_nome}</td>
                    <td>{formatarMoeda(pagamento.valor)}</td>
                    <td>
                      <Etiqueta {...etiquetaPagamento(pagamento.situacao)} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </section>
  );
}