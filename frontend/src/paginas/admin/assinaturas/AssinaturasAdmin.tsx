import { useCallback, useState } from 'react';
import type { FormEvent } from 'react';
import { Link } from 'react-router-dom';
import Etiqueta from '../../../componentes/comum/Etiqueta';
import { useCarregar } from '../../../hooks/useCarregar';
import { listarAssinaturasAdmin } from '../../../servicos/assinaturas-admin.servico';
import type {
  FiltroAssinaturasAdmin,
  SituacaoAssinaturaAdmin,
} from '../../../tipos/assinaturas-admin.tipos';
import {
  dataOuTraco,
  etiquetaSituacao,
  OPCOES_SITUACAO,
  rotuloOrigem,
} from '../../../utilitarios/rotulos-assinaturas';
import '../../../componentes/comum/comum.css';
import '../../../estilos/assinaturas.css';
import '../../../estilos/admin.css';

const FILTRO_INICIAL: FiltroAssinaturasAdmin = { busca: '', situacao: '', pagina: 1 };

// RF17 – Gerenciar Assinaturas: listar, pesquisar e filtrar por situação
export default function AssinaturasAdmin() {
  // O que está digitado/escolhido (só vale depois de clicar em Pesquisar)
  const [busca, setBusca] = useState('');
  const [situacao, setSituacao] = useState<'' | SituacaoAssinaturaAdmin>('');
  // O filtro aplicado de fato
  const [filtro, setFiltro] = useState<FiltroAssinaturasAdmin>(FILTRO_INICIAL);

  const buscar = useCallback(() => listarAssinaturasAdmin(filtro), [filtro]);
  const { dados, carregando, erro } = useCarregar(buscar);

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

  const totalPaginas = dados ? Math.max(1, Math.ceil(dados.total / dados.limite)) : 1;

  return (
    <section className="pagina">
      <div>
        <h1>Assinaturas</h1>
        <p className="texto-secundario">Acompanhe e controle as assinaturas dos motoristas.</p>
      </div>

      <form className="card filtro-assinantes" onSubmit={pesquisar}>
        <div className="grupo-campo">
          <label className="rotulo" htmlFor="busca-assinatura">
            Usuário ou plano
          </label>
          <input
            id="busca-assinatura"
            className="campo"
            type="text"
            maxLength={150}
            placeholder="Nome, e-mail ou plano"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
          />
        </div>

        <div className="grupo-campo">
          <label className="rotulo" htmlFor="filtro-situacao">
            Situação
          </label>
          <select
            id="filtro-situacao"
            className="campo"
            value={situacao}
            onChange={(e) => setSituacao(e.target.value as '' | SituacaoAssinaturaAdmin)}
          >
            <option value="">Todas</option>
            {OPCOES_SITUACAO.map((opcao) => (
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

      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}

      {carregando && !dados && <p className="texto-secundario">Carregando...</p>}

      {dados && dados.itens.length === 0 && (
        <p className="texto-secundario">Nenhuma assinatura encontrada.</p>
      )}

      {dados && dados.itens.length > 0 && (
        <div className="card">
          <div className="tabela-container">
            <table className="tabela">
              <thead>
                <tr>
                  <th>Assinante</th>
                  <th>Plano</th>
                  <th>Situação</th>
                  <th>Origem</th>
                  <th>Início</th>
                  <th>Vencimento</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {dados.itens.map((assinatura) => (
                  <tr key={assinatura.id_assinatura}>
                    <td>
                      {assinatura.usuario.nome}
                      <br />
                      <span className="texto-secundario">{assinatura.usuario.email}</span>
                    </td>
                    <td>{assinatura.plano.nome}</td>
                    <td>
                      <Etiqueta {...etiquetaSituacao(assinatura.situacao)} />
                    </td>
                    <td>{rotuloOrigem(assinatura.origem)}</td>
                    <td>{dataOuTraco(assinatura.data_inicio)}</td>
                    <td>{dataOuTraco(assinatura.data_vencimento)}</td>
                    <td>
                      <Link
                        className="botao-secundario botao-pequeno link-botao"
                        to={`/admin/assinaturas/${assinatura.id_assinatura}`}
                      >
                        Detalhes
                      </Link>
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
              Página {dados.pagina} de {totalPaginas} · {dados.total} assinatura(s)
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
    </section>
  );
}