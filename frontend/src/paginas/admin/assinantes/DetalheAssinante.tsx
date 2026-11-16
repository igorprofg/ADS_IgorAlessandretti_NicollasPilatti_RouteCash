import { useCallback, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import Etiqueta from '../../../componentes/comum/Etiqueta';
import ModalConfirmacao from '../../../componentes/comum/ModalConfirmacao';
import { useCarregar } from '../../../hooks/useCarregar';
import {
  ativarAssinante,
  bloquearAssinante,
  buscarAssinante,
  suspenderAssinante,
} from '../../../servicos/assinantes.servico';
import type { AssinanteDetalhe } from '../../../tipos/admin.tipos';
import { formatarData, formatarMoeda } from '../../../utilitarios/formatadores';
import { mensagemDeErro } from '../../../utilitarios/mensagem-erro';
import { etiquetaAssinatura, sufixoPeriodo } from '../../../utilitarios/rotulos';
import { etiquetaConta } from '../../../utilitarios/rotulos-admin';
import '../../../componentes/comum/comum.css';
import '../../../estilos/assinaturas.css';
import '../../../estilos/admin.css';

type Acao = 'ativar' | 'suspender' | 'bloquear';

const EXECUTAR: Record<Acao, (id: string) => Promise<AssinanteDetalhe>> = {
  ativar: ativarAssinante,
  suspender: suspenderAssinante,
  bloquear: bloquearAssinante,
};

const TEXTOS: Record<
  Acao,
  { titulo: string; confirmar: string; explicacao: string; sucesso: string; perigo: boolean }
> = {
  ativar: {
    titulo: 'Ativar assinante?',
    confirmar: 'Sim, ativar',
    explicacao: 'O assinante volta a poder acessar o RouteCash.',
    sucesso: 'Assinante ativado.',
    perigo: false,
  },
  suspender: {
    titulo: 'Suspender assinante?',
    confirmar: 'Sim, suspender',
    explicacao:
      'O acesso do assinante fica restrito temporariamente. Os dados dele são preservados.',
    sucesso: 'Assinante suspenso.',
    perigo: true,
  },
  bloquear: {
    titulo: 'Bloquear assinante?',
    confirmar: 'Sim, bloquear',
    explicacao:
      'O assinante não consegue mais acessar o sistema. Os dados dele são preservados.',
    sucesso: 'Assinante bloqueado.',
    perigo: true,
  },
};

// RF15: dados do assinante (HU41) e ações de ativar, suspender e bloquear (HU42 a HU44)
export default function DetalheAssinante() {
  const { id = '' } = useParams();

  const buscar = useCallback(() => buscarAssinante(id), [id]);
  const { dados: assinante, carregando, erro, recarregar } = useCarregar(buscar);

  const [acao, setAcao] = useState<Acao | null>(null);
  const [processando, setProcessando] = useState(false);
  const [erroAcao, setErroAcao] = useState('');
  const [sucesso, setSucesso] = useState('');

  async function confirmar() {
    if (!acao) return;
    setProcessando(true);
    setErroAcao('');

    try {
      await EXECUTAR[acao](id);
      setSucesso(TEXTOS[acao].sucesso);
      setAcao(null);
      recarregar();
    } catch (e) {
      setErroAcao(mensagemDeErro(e, 'Não foi possível concluir a operação'));
    } finally {
      setProcessando(false);
    }
  }

  const assinatura = assinante?.assinatura_atual ?? null;

  return (
    <section className="pagina">
      <Link to="/admin/assinantes" className="voltar">
        ← Voltar aos assinantes
      </Link>

      {sucesso && <p className="mensagem-sucesso">{sucesso}</p>}
      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}
      {carregando && !assinante && <p className="texto-secundario">Carregando...</p>}

      {assinante && (
        <>
          <div className="card detalhe-assinante">
            <div className="cartao-plano-topo">
              <h1>{assinante.nome}</h1>
              <Etiqueta {...etiquetaConta(assinante.status_conta)} />
            </div>

            <div className="linha-info">
              <span>E-mail</span>
              <span>{assinante.email}</span>
            </div>
            <div className="linha-info">
              <span>Cadastrado em</span>
              <span>{new Date(assinante.data_cadastro).toLocaleDateString('pt-BR')}</span>
            </div>
            <div className="linha-info">
              <span>Aceitou os Termos de Uso em</span>
              <span>{new Date(assinante.aceite_termos_em).toLocaleDateString('pt-BR')}</span>
            </div>

            <div className="acoes-assinante">
              {assinante.status_conta !== 'ATIVO' && (
                <button className="botao" onClick={() => setAcao('ativar')}>
                  Ativar
                </button>
              )}
              {assinante.status_conta === 'ATIVO' && (
                <button className="botao-secundario" onClick={() => setAcao('suspender')}>
                  Suspender
                </button>
              )}
              {assinante.status_conta !== 'BLOQUEADO' && (
                <button className="botao botao-perigo" onClick={() => setAcao('bloquear')}>
                  Bloquear
                </button>
              )}
            </div>
          </div>

          <div className="card detalhe-assinante">
            <h2>Assinatura atual</h2>
            {assinatura ? (
              <>
                <div className="linha-info">
                  <span>Plano</span>
                  <span>{assinatura.plano.nome}</span>
                </div>
                <div className="linha-info">
                  <span>Valor</span>
                  <span>
                    {formatarMoeda(assinatura.plano.valor)} /{' '}
                    {sufixoPeriodo(assinatura.plano.periodo_cobranca)}
                  </span>
                </div>
                <div className="linha-info">
                  <span>Situação</span>
                  <span>
                    <Etiqueta {...etiquetaAssinatura(assinatura.situacao)} />
                  </span>
                </div>
                <div className="linha-info">
                  <span>Início</span>
                  <span>{formatarData(assinatura.data_inicio)}</span>
                </div>
                <div className="linha-info">
                  <span>Vencimento</span>
                  <span>
                    {formatarData(assinatura.data_vencimento)}
                    {assinatura.vencida && <Etiqueta texto="Vencida" tipo="negativo" />}
                  </span>
                </div>
              </>
            ) : (
              <p className="texto-secundario">Este assinante não possui assinatura em aberto.</p>
            )}
          </div>
        </>
      )}

      {acao && assinante && (
        <ModalConfirmacao
          titulo={TEXTOS[acao].titulo}
          textoConfirmar={TEXTOS[acao].confirmar}
          perigo={TEXTOS[acao].perigo}
          processando={processando}
          erro={erroAcao}
          aoConfirmar={confirmar}
          aoCancelar={() => setAcao(null)}
        >
          <p>
            <strong>{assinante.nome}</strong> ({assinante.email})
          </p>
          <p className="texto-secundario">{TEXTOS[acao].explicacao}</p>
        </ModalConfirmacao>
      )}
    </section>
  );
}