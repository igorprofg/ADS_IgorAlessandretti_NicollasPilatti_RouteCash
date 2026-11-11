import { useCallback, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import Etiqueta from '../../componentes/comum/Etiqueta';
import ModalConfirmacao from '../../componentes/comum/ModalConfirmacao';
import { useCarregar } from '../../hooks/useCarregar';
import { contratarPlano } from '../../servicos/assinaturas.servico';
import { buscarPlano } from '../../servicos/planos.servico';
import { formatarMoeda } from '../../utilitarios/formatadores';
import { mensagemDeErro } from '../../utilitarios/mensagem-erro';
import { listarBeneficios, rotuloPeriodo } from '../../utilitarios/rotulos';
import '../../estilos/assinaturas.css';

// HU36 (detalhes do plano) e HU37 (contratar, com os dados à vista antes de confirmar)
export default function DetalhePlano() {
  const { id = '' } = useParams();
  const navegar = useNavigate();

  const buscar = useCallback(() => buscarPlano(id), [id]);
  const { dados: plano, carregando, erro } = useCarregar(buscar);

  const [confirmando, setConfirmando] = useState(false);
  const [processando, setProcessando] = useState(false);
  const [erroContratacao, setErroContratacao] = useState('');

  async function confirmarContratacao() {
    if (!plano) return;
    setProcessando(true);
    setErroContratacao('');

    try {
      await contratarPlano(plano.id_plano);
      navegar('/assinatura', { state: { contratado: true } });
    } catch (e) {
      setErroContratacao(mensagemDeErro(e, 'Não foi possível contratar o plano'));
      setProcessando(false);
    }
  }

  return (
    <section className="pagina">
      <Link to="/planos" className="voltar">
        ← Voltar aos planos
      </Link>

      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}
      {carregando && !plano && <p className="texto-secundario">Carregando...</p>}

      {plano && (
        <div className="card detalhe-plano">
          <div className="cartao-plano-topo">
            <h1>{plano.nome}</h1>
            {plano.contratado ? (
              <Etiqueta texto="Seu plano atual" tipo="positivo" />
            ) : plano.disponivel_para_contratacao ? (
              <Etiqueta texto="Disponível para contratação" tipo="positivo" />
            ) : (
              <Etiqueta texto="Indisponível para contratação" tipo="neutro" />
            )}
          </div>

          <div className="linha-info">
            <span>Valor</span>
            <span>{formatarMoeda(plano.valor)}</span>
          </div>
          <div className="linha-info">
            <span>Cobrança</span>
            <span>{rotuloPeriodo(plano.periodo_cobranca)}</span>
          </div>

          <h2>Benefícios</h2>
          <ul className="lista-beneficios">
            {listarBeneficios(plano.beneficios).map((beneficio) => (
              <li key={beneficio}>{beneficio}</li>
            ))}
          </ul>

          {plano.disponivel_para_contratacao && (
            <div className="acoes-assinatura">
              <button className="botao" onClick={() => setConfirmando(true)}>
                Contratar plano
              </button>
            </div>
          )}

          {!plano.contratado && !plano.disponivel_para_contratacao && (
            <p className="texto-secundario">
              {plano.ativo
                ? 'Você já possui uma assinatura em aberto. Cancele-a para contratar outro plano.'
                : 'Este plano não está mais disponível para contratação.'}
            </p>
          )}
        </div>
      )}

      {confirmando && plano && (
        <ModalConfirmacao
          titulo="Confirmar contratação"
          textoConfirmar="Confirmar contratação"
          processando={processando}
          erro={erroContratacao}
          aoConfirmar={confirmarContratacao}
          aoCancelar={() => setConfirmando(false)}
        >
          <div className="linha-info">
            <span>Plano</span>
            <span>{plano.nome}</span>
          </div>
          <div className="linha-info">
            <span>Valor</span>
            <span>{formatarMoeda(plano.valor)}</span>
          </div>
          <div className="linha-info">
            <span>Cobrança</span>
            <span>{rotuloPeriodo(plano.periodo_cobranca)}</span>
          </div>
        </ModalConfirmacao>
      )}
    </section>
  );
}