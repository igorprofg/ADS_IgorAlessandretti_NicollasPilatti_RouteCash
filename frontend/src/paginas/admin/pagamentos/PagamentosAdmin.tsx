import { useCallback, useState } from 'react';
import type { FormEvent } from 'react';
import { Link } from 'react-router-dom';
import Etiqueta from '../../../componentes/comum/Etiqueta';
import ModalConfirmacao from '../../../componentes/comum/ModalConfirmacao';
import { useCarregar } from '../../../hooks/useCarregar';
import {
  atualizarSituacaoPagamento,
  listarPagamentosAdmin,
} from '../../../servicos/pagamentos-admin.servico';
import type { SituacaoPagamento } from '../../../tipos/assinaturas.tipos';
import type {
  FiltroPagamentosAdmin,
  PagamentoAdmin,
} from '../../../tipos/pagamentos-admin.tipos';
import { formatarData, formatarMoeda, SEM_VALOR } from '../../../utilitarios/formatadores';
import { mensagemDeErro } from '../../../utilitarios/mensagem-erro';
import { periodoDoPreset } from '../../../utilitarios/periodos';
import { etiquetaPagamento } from '../../../utilitarios/rotulos';
import { OPCOES_SITUACAO_PAGAMENTO } from '../../../utilitarios/rotulos-pagamentos';
import '../../../componentes/comum/comum.css';
import '../../../estilos/assinaturas.css';
import '../../../estilos/admin.css';

const FILTRO_INICIAL: FiltroPagamentosAdmin = { busca: '', situacao: '', pagina: 1 };

// RF18 – Gerenciar Pagamentos: lista, pesquisa, filtro e atualização da situação (HU53 e HU54)
export default function PagamentosAdmin() {
  const [busca, setBusca] = useState('');
  const [situacao, setSituacao] = useState<'' | SituacaoPagamento>('');
  const [filtro, setFiltro] = useState<FiltroPagamentosAdmin>(FILTRO_INICIAL);

  const buscar = useCallback(() => listarPagamentosAdmin(filtro), [filtro]);
  const { dados, carregando, erro, recarregar } = useCarregar(buscar);

  // Janela "Atualizar situação"
  const [alvo, setAlvo] = useState<PagamentoAdmin | null>(null);
  const [novaSituacao, setNovaSituacao] = useState<SituacaoPagamento>('PAGO');
  const [dataPagamento, setDataPagamento] = useState('');
  const [processando, setProcessando] = useState(false);
  const [erroAcao, setErroAcao] = useState('');
  const [sucesso, setSucesso] = useState('');

  function pesquisar(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault();
    setFiltro({ busca: busca.trim(), situacao, pagina: 1 });
  }

  function limpar() {
    setBusca('');
    setSituacao('');
    setFiltro(FILTRO_INICIAL);
  }

  function irParaPagina(pagina: number) {
    setFiltro((atual) => ({ ...atual, pagina }));
  }

  function abrirAtualizacao(pagamento: PagamentoAdmin) {
    const primeira = OPCOES_SITUACAO_PAGAMENTO.find((o) => o.valor !== pagamento.situacao);
    setAlvo(pagamento);
    setNovaSituacao(primeira ? primeira.valor : 'PAGO');
    setDataPagamento(periodoDoPreset('hoje').inicio);
    setErroAcao('');
  }

  async function confirmar() {
    if (!alvo) return;
    if (novaSituacao === 'PAGO' && !dataPagamento) {
      setErroAcao('Informe a data do pagamento');
      return;
    }

    setProcessando(true);
    setErroAcao('');
    try {
      await atualizarSituacaoPagamento(alvo.id_pagamento, novaSituacao, dataPagamento);
      setSucesso('Situação do pagamento atualizada.');
      setAlvo(null);
      recarregar();
    } catch (e) {
      setErroAcao(mensagemDeErro(e, 'Não foi possível atualizar o pagamento'));
    } finally {
      setProcessando(false);
    }
  }

  const totalPaginas = dados ? Math.max(1, Math.ceil(dados.total / dados.limite)) : 1;

  return (
    <section className="pagina">
      <div className="cabecalho-pagina">
        <div>
          <h1>Pagamentos</h1>
          <p className="texto-secundario">Registre e acompanhe os pagamentos das assinaturas.</p>
        </div>
        <Link to="/admin/pagamentos/novo" className="botao link-botao">
          Registrar pagamento
        </Link>
      </div>

      <form className="card filtro-assinantes" onSubmit={pesquisar}>
        <div className="grupo-campo">
          <label className="rotulo" htmlFor="busca-pagamento">
            Usuário ou plano
          </label>
          <input
            id="busca-pagamento"
            className="campo"
            type="text"
            maxLength={150}
            placeholder="Nome, e-mail ou plano"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
          />
        </div>

        <div className="grupo-campo">
          <label className="rotulo" htmlFor="filtro-situacao-pagamento">
            Situação
          </label>
          <select
            id="filtro-situacao-pagamento"
            className="campo"
            value={situacao}
            onChange={(e) => setSituacao(e.target.value as '' | SituacaoPagamento)}
          >
            <option value="">Todas</option>
            {OPCOES_SITUACAO_PAGAMENTO.map((opcao) => (
              <option key={opcao.valor} value={opcao.valor}>
                {opcao.rotulo}
              </option>
            ))}
          </select>
        </div>

        <button className="botao" type="submit">
          Pesquisar
        </button>
        <button className="botao-secundario" type="button" onClick={limpar}>
          Limpar
        </button>
      </form>

      {sucesso && <p className="mensagem-sucesso">{sucesso}</p>}
      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}
      {carregando && !dados && <p className="texto-secundario">Carregando...</p>}

      {dados && dados.itens.length === 0 && (
        <p className="texto-secundario">Nenhum pagamento encontrado.</p>
      )}

      {dados && dados.itens.length > 0 && (
        <div className="card">
          <div className="tabela-container">
            <table className="tabela">
              <thead>
                <tr>
                  <th>Assinante</th>
                  <th>Plano</th>
                  <th>Vencimento</th>
                  <th>Pago em</th>
                  <th>Valor</th>
                  <th>Situação</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {dados.itens.map((pagamento) => (
                  <tr key={pagamento.id_pagamento}>
                    <td>
                      {pagamento.usuario.nome}
                      <br />
                      <span className="texto-secundario">{pagamento.usuario.email}</span>
                    </td>
                    <td>{pagamento.plano_nome}</td>
                    <td>{formatarData(pagamento.data_vencimento)}</td>
                    <td>
                      {pagamento.data_pagamento ? formatarData(pagamento.data_pagamento) : SEM_VALOR}
                    </td>
                    <td>{formatarMoeda(pagamento.valor)}</td>
                    <td>
                      <Etiqueta {...etiquetaPagamento(pagamento.situacao)} />{' '}
                      {pagamento.em_atraso && <Etiqueta texto="Em atraso" tipo="negativo" />}
                    </td>
                    <td>
                      {pagamento.origem === 'ASAAS' ? (
                        <span className="texto-secundario">Gerenciado pelo Asaas</span>
                      ) : (
                        <button
                          className="botao-secundario botao-pequeno"
                          onClick={() => abrirAtualizacao(pagamento)}
                        >
                          Atualizar situação
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="paginacao">
            <button
              className="botao-secundario"
              disabled={dados.pagina <= 1 || carregando}
              onClick={() => irParaPagina(dados.pagina - 1)}
            >
              Anterior
            </button>
            <span className="texto-secundario">
              Página {dados.pagina} de {totalPaginas} · {dados.total} pagamento(s)
            </span>
            <button
              className="botao-secundario"
              disabled={dados.pagina >= totalPaginas || carregando}
              onClick={() => irParaPagina(dados.pagina + 1)}
            >
              Próxima
            </button>
          </div>
        </div>
      )}

      {alvo && (
        <ModalConfirmacao
          titulo="Atualizar situação do pagamento"
          textoConfirmar="Salvar"
          processando={processando}
          erro={erroAcao}
          aoConfirmar={confirmar}
          aoCancelar={() => setAlvo(null)}
        >
          <p>
            <strong>{alvo.usuario.nome}</strong> · {alvo.plano_nome} · vence em{' '}
            {formatarData(alvo.data_vencimento)} · {formatarMoeda(alvo.valor)}
          </p>

          <div className="formulario">
            <div className="grupo-campo">
              <label className="rotulo" htmlFor="nova-situacao">
                Nova situação
              </label>
              <select
                id="nova-situacao"
                className="campo"
                value={novaSituacao}
                onChange={(e) => setNovaSituacao(e.target.value as SituacaoPagamento)}
              >
                {OPCOES_SITUACAO_PAGAMENTO.filter((o) => o.valor !== alvo.situacao).map(
                  (opcao) => (
                    <option key={opcao.valor} value={opcao.valor}>
                      {opcao.rotulo}
                    </option>
                  ),
                )}
              </select>
            </div>

            {novaSituacao === 'PAGO' && (
              <div className="grupo-campo">
                <label className="rotulo" htmlFor="data-pagamento">
                  Data do pagamento
                </label>
                <input
                  id="data-pagamento"
                  className="campo"
                  type="date"
                  max={periodoDoPreset('hoje').inicio}
                  value={dataPagamento}
                  onChange={(e) => setDataPagamento(e.target.value)}
                />
              </div>
            )}
          </div>
        </ModalConfirmacao>
      )}
    </section>
  );
}