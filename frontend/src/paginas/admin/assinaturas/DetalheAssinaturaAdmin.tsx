import { useCallback, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import Etiqueta from '../../../componentes/comum/Etiqueta';
import ModalConfirmacao from '../../../componentes/comum/ModalConfirmacao';
import { useCarregar } from '../../../hooks/useCarregar';
import {
  ativarAssinaturaAdmin,
  buscarAssinaturaAdmin,
  cancelarAssinaturaAdmin,
  reativarAssinatura,
  suspenderAssinatura,
} from '../../../servicos/assinaturas-admin.servico';
import type { AssinaturaAdminDetalhe } from '../../../tipos/assinaturas-admin.tipos';
import { formatarMoeda } from '../../../utilitarios/formatadores';
import { mensagemDeErro } from '../../../utilitarios/mensagem-erro';
import { sufixoPeriodo } from '../../../utilitarios/rotulos';
import { etiquetaConta } from '../../../utilitarios/rotulos-admin';
import {
  dataOuTraco,
  etiquetaSituacao,
  rotuloOrigem,
} from '../../../utilitarios/rotulos-assinaturas';
import '../../../componentes/comum/comum.css';
import '../../../estilos/assinaturas.css';
import '../../../estilos/admin.css';

type Acao = 'ativar' | 'suspender' | 'reativar' | 'cancelar';

const EXECUTAR: Record<Acao, (id: string) => Promise<AssinaturaAdminDetalhe>> = {
  ativar: ativarAssinaturaAdmin,
  suspender: suspenderAssinatura,
  reativar: reativarAssinatura,
  cancelar: cancelarAssinaturaAdmin,
};

const TEXTOS: Record<
  Acao,
  { titulo: string; confirmar: string; explicacao: string; sucesso: string; perigo: boolean }
> = {
  ativar: {
    titulo: 'Ativar assinatura?',
    confirmar: 'Sim, ativar',
    explicacao:
      'Confirme que o pagamento foi recebido (registre-o em Pagamentos). A assinatura fica ativa a partir de hoje, com vencimento pelo período do plano.',
    sucesso: 'Assinatura ativada.',
    perigo: false,
  },
  suspender: {
    titulo: 'Suspender assinatura?',
    confirmar: 'Sim, suspender',
    explicacao: 'A assinatura fica suspensa até ser reativada. Os dados são preservados.',
    sucesso: 'Assinatura suspensa.',
    perigo: true,
  },
  reativar: {
    titulo: 'Reativar assinatura?',
    confirmar: 'Sim, reativar',
    explicacao: 'A assinatura volta a ficar ativa.',
    sucesso: 'Assinatura reativada.',
    perigo: false,
  },
  cancelar: {
    titulo: 'Cancelar assinatura?',
    confirmar: 'Sim, cancelar',
    explicacao:
      'A assinatura é encerrada e não pode ser reativada. O registro continua no histórico.',
    sucesso: 'Assinatura cancelada.',
    perigo: true,
  },
};

// RF17: dados da assinatura e ações de suspender, reativar e cancelar
export default function DetalheAssinaturaAdmin() {
  const { id = '' } = useParams();

  const buscar = useCallback(() => buscarAssinaturaAdmin(id), [id]);
  const { dados: assinatura, carregando, erro, recarregar } = useCarregar(buscar);

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

  return (
    <section className="pagina">
      <Link to="/admin/assinaturas" className="voltar">
        ← Voltar às assinaturas
      </Link>

      {sucesso && <p className="mensagem-sucesso">{sucesso}</p>}
      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}
      {carregando && !assinatura && <p className="texto-secundario">Carregando...</p>}

      {assinatura && (
        <>
          <div className="card detalhe-assinante">
            <div className="cartao-plano-topo">
              <h1>{assinatura.plano.nome}</h1>
              <Etiqueta {...etiquetaSituacao(assinatura.situacao)} />
            </div>

            <div className="linha-info">
              <span>Valor</span>
              <span>
                {formatarMoeda(assinatura.plano.valor)} /{' '}
                {sufixoPeriodo(assinatura.plano.periodo_cobranca)}
              </span>
            </div>
            <div className="linha-info">
              <span>Origem</span>
              <span>{rotuloOrigem(assinatura.origem)}</span>
            </div>
            <div className="linha-info">
              <span>Início</span>
              <span>{dataOuTraco(assinatura.data_inicio)}</span>
            </div>
            <div className="linha-info">
              <span>Vencimento</span>
              <span>
                {dataOuTraco(assinatura.data_vencimento)}
                {assinatura.vencida && <Etiqueta texto="Vencida" tipo="negativo" />}
              </span>
            </div>
            {assinatura.data_cancelamento && (
              <div className="linha-info">
                <span>Cancelada em</span>
                <span>{new Date(assinatura.data_cancelamento).toLocaleDateString('pt-BR')}</span>
              </div>
            )}

            {assinatura.vinculo_asaas && (
              <p className="texto-secundario">
                Esta assinatura tem vínculo com o Asaas. As ações abaixo valem apenas no Route
                Cash: a cobrança recorrente no Asaas precisa ser ajustada ou cancelada no painel
                do Asaas até que a sincronização automática seja implementada.
              </p>
            )}

            <div className="acoes-assinante">
              {assinatura.situacao === 'PENDENTE' && assinatura.origem === 'MANUAL' && (
                <button className="botao" onClick={() => setAcao('ativar')}>
                  Ativar assinatura
                </button>
              )}
              {assinatura.situacao === 'ATIVA' && (
                <button className="botao-secundario" onClick={() => setAcao('suspender')}>
                  Suspender
                </button>
              )}
              {assinatura.situacao === 'SUSPENSA' && (
                <button className="botao" onClick={() => setAcao('reativar')}>
                  Reativar
                </button>
              )}
              {assinatura.situacao !== 'CANCELADA' && (
                <button className="botao botao-perigo" onClick={() => setAcao('cancelar')}>
                  Cancelar assinatura
                </button>
              )}
            </div>
          </div>

          <div className="card detalhe-assinante">
            <h2>Assinante</h2>
            <div className="linha-info">
              <span>Nome</span>
              <span>{assinatura.usuario.nome}</span>
            </div>
            <div className="linha-info">
              <span>E-mail</span>
              <span>{assinatura.usuario.email}</span>
            </div>
            <div className="linha-info">
              <span>Conta</span>
              <span>
                <Etiqueta {...etiquetaConta(assinatura.usuario.status_conta)} />
              </span>
            </div>
            <div className="acoes-assinante">
              <Link
                to={`/admin/assinantes/${assinatura.usuario.id_usuario}`}
                className="botao-secundario link-botao"
              >
                Ver assinante
              </Link>
            </div>
          </div>
        </>
      )}

      {acao && assinatura && (
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
            <strong>{assinatura.plano.nome}</strong> · {assinatura.usuario.nome}
          </p>
          <p className="texto-secundario">{TEXTOS[acao].explicacao}</p>
          {assinatura.vinculo_asaas && (
            <p className="texto-secundario">
              Atenção: a alteração vale só no Route Cash. Ajuste também a cobrança no painel do
              Asaas.
            </p>
          )}
        </ModalConfirmacao>
      )}
    </section>
  );
}