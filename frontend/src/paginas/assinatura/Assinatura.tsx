import { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import Etiqueta from '../../componentes/comum/Etiqueta';
import ModalConfirmacao from '../../componentes/comum/ModalConfirmacao';
import { useCarregar } from '../../hooks/useCarregar';
import {
  buscarAssinaturaAtual,
  cancelarAssinaturaAtual,
  listarAssinaturas,
} from '../../servicos/assinaturas.servico';
import {
  formatarData,
  formatarMoeda,
  SEM_VALOR,
} from '../../utilitarios/formatadores';
import { mensagemDeErro } from '../../utilitarios/mensagem-erro';
import { etiquetaAssinatura, sufixoPeriodo } from '../../utilitarios/rotulos';
import '../../componentes/comum/comum.css';
import '../../estilos/assinaturas.css';

// RF13: assinatura atual (HU38), cancelamento com confirmação (HU39) e histórico
export default function Assinatura() {
  const local = useLocation();
  const contratadoAgora = Boolean(local.state?.contratado);

  const atualCarga = useCarregar(buscarAssinaturaAtual);
  const historicoCarga = useCarregar(listarAssinaturas);

  const [cancelando, setCancelando] = useState(false);
  const [processando, setProcessando] = useState(false);
  const [erroCancelamento, setErroCancelamento] = useState('');
  const [canceladaAgora, setCanceladaAgora] = useState(false);

  const atual = atualCarga.dados;

  async function confirmarCancelamento() {
    setProcessando(true);
    setErroCancelamento('');

    try {
      await cancelarAssinaturaAtual();
      setCancelando(false);
      setCanceladaAgora(true);
      atualCarga.recarregar();
      historicoCarga.recarregar();
    } catch (e) {
      setErroCancelamento(mensagemDeErro(e, 'Não foi possível cancelar a assinatura'));
    } finally {
      setProcessando(false);
    }
  }

  return (
    <section className="pagina">
      <div>
        <h1>Assinatura</h1>
        <p className="texto-secundario">Acompanhe e gerencie o seu plano.</p>
      </div>

      {contratadoAgora && !canceladaAgora && (
        <p className="mensagem-sucesso">Plano contratado com sucesso!</p>
      )}
      {canceladaAgora && (
        <p className="mensagem-sucesso">
          Assinatura cancelada. O registro foi mantido no seu histórico.
        </p>
      )}

      {atualCarga.erro && (
        <p className="mensagem-erro" role="alert">
          {atualCarga.erro}
        </p>
      )}

      {atualCarga.carregando && <p className="texto-secundario">Carregando...</p>}

      {!atualCarga.carregando && atual && (
        <div className="card">
          <div className="cartao-plano-topo">
            <h2>{atual.plano.nome}</h2>
            <Etiqueta {...etiquetaAssinatura(atual.situacao)} />
          </div>

          <div className="linha-info">
            <span>Valor</span>
            <span>
              {formatarMoeda(atual.plano.valor)} / {sufixoPeriodo(atual.plano.periodo_cobranca)}
            </span>
          </div>
          <div className="linha-info">
            <span>Início</span>
            <span>{formatarData(atual.data_inicio)}</span>
          </div>
          <div className="linha-info">
            <span>Vencimento</span>
            <span>
              {formatarData(atual.data_vencimento)}
              {atual.vencida && <Etiqueta texto="Vencida" tipo="negativo" />}
            </span>
          </div>

          <div className="acoes-assinatura">
            <button className="botao botao-perigo" onClick={() => setCancelando(true)}>
              Cancelar assinatura
            </button>
            <Link to="/planos" className="botao-secundario link-botao">
              Ver planos
            </Link>
          </div>
        </div>
      )}

      {!atualCarga.carregando && !atualCarga.erro && !atual && (
        <div className="card estado-vazio">
          <p className="texto-secundario">Você ainda não possui uma assinatura ativa.</p>
          <Link to="/planos" className="botao link-botao">
            Ver planos
          </Link>
        </div>
      )}

      {historicoCarga.dados && historicoCarga.dados.length > 0 && (
        <div className="card">
          <h2>Histórico de assinaturas</h2>
          <div className="tabela-container">
            <table className="tabela">
              <thead>
                <tr>
                  <th>Plano</th>
                  <th>Início</th>
                  <th>Vencimento</th>
                  <th>Situação</th>
                  <th>Cancelada em</th>
                </tr>
              </thead>
              <tbody>
                {historicoCarga.dados.map((assinatura) => (
                  <tr key={assinatura.id_assinatura}>
                    <td>{assinatura.plano.nome}</td>
                    <td>{formatarData(assinatura.data_inicio)}</td>
                    <td>{formatarData(assinatura.data_vencimento)}</td>
                    <td>
                      <Etiqueta {...etiquetaAssinatura(assinatura.situacao)} />
                    </td>
                    <td>
                      {assinatura.data_cancelamento
                        ? new Date(assinatura.data_cancelamento).toLocaleDateString('pt-BR')
                        : SEM_VALOR}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {cancelando && atual && (
        <ModalConfirmacao
          titulo="Cancelar assinatura?"
          textoConfirmar="Sim, cancelar"
          perigo
          processando={processando}
          erro={erroCancelamento}
          aoConfirmar={confirmarCancelamento}
          aoCancelar={() => setCancelando(false)}
        >
          <p>
            Você está cancelando o plano <strong>{atual.plano.nome}</strong>. O registro da
            assinatura continua no seu histórico, e você poderá contratar um plano novamente
            depois.
          </p>
        </ModalConfirmacao>
      )}
    </section>
  );
}