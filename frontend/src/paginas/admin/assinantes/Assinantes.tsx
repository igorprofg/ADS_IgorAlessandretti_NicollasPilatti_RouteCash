import { useCallback, useState } from 'react';
import type { FormEvent } from 'react';
import { Link } from 'react-router-dom';
import Etiqueta from '../../../componentes/comum/Etiqueta';
import { useCarregar } from '../../../hooks/useCarregar';
import { listarAssinantes } from '../../../servicos/assinantes.servico';
import type { FiltroAssinantes } from '../../../tipos/admin.tipos';
import { formatarData, SEM_VALOR } from '../../../utilitarios/formatadores';
import { etiquetaAssinatura } from '../../../utilitarios/rotulos';
import { etiquetaConta } from '../../../utilitarios/rotulos-admin';
import '../../../componentes/comum/comum.css';
import '../../../estilos/assinaturas.css';
import '../../../estilos/admin.css';

const FILTRO_INICIAL: FiltroAssinantes = { nome: '', email: '', pagina: 1 };

// RF15 – Gerenciar Assinantes (HU41): lista com busca por nome e e-mail
export default function Assinantes() {
  // O que está digitado nos campos (só vale depois de clicar em Pesquisar)
  const [nome, setNome] = useState('');
  const [email, setEmail] = useState('');
  // O filtro aplicado de fato
  const [filtro, setFiltro] = useState<FiltroAssinantes>(FILTRO_INICIAL);

  const buscar = useCallback(() => listarAssinantes(filtro), [filtro]);
  const { dados, carregando, erro } = useCarregar(buscar);

  function pesquisar(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault();
    setFiltro({ nome: nome.trim(), email: email.trim(), pagina: 1 });
  }

  function limpar() {
    setNome('');
    setEmail('');
    setFiltro(FILTRO_INICIAL);
  }

  function irParaPagina(pagina: number) {
    setFiltro((atual) => ({ ...atual, pagina }));
  }

  const totalPaginas = dados ? Math.max(1, Math.ceil(dados.total / dados.limite)) : 1;

  return (
    <section className="pagina">
      <div>
        <h1>Assinantes</h1>
        <p className="texto-secundario">
          Consulte os motoristas cadastrados e controle o acesso deles.
        </p>
      </div>

      <form className="card filtro-assinantes" onSubmit={pesquisar}>
        <div className="grupo-campo">
          <label className="rotulo" htmlFor="busca-nome">
            Nome
          </label>
          <input
            id="busca-nome"
            className="campo"
            type="text"
            maxLength={100}
            value={nome}
            onChange={(e) => setNome(e.target.value)}
          />
        </div>

        <div className="grupo-campo">
          <label className="rotulo" htmlFor="busca-email">
            E-mail
          </label>
          <input
            id="busca-email"
            className="campo"
            type="text"
            maxLength={150}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
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
        <p className="texto-secundario">Nenhum assinante encontrado.</p>
      )}

      {dados && dados.itens.length > 0 && (
        <div className="card">
          <div className="tabela-container">
            <table className="tabela">
              <thead>
                <tr>
                  <th>Nome</th>
                  <th>E-mail</th>
                  <th>Conta</th>
                  <th>Plano</th>
                  <th>Assinatura</th>
                  <th>Vencimento</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {dados.itens.map((assinante) => {
                  const assinatura = assinante.assinatura_atual;
                  return (
                    <tr key={assinante.id_usuario}>
                      <td>{assinante.nome}</td>
                      <td>{assinante.email}</td>
                      <td>
                        <Etiqueta {...etiquetaConta(assinante.status_conta)} />
                      </td>
                      <td>{assinatura ? assinatura.plano.nome : SEM_VALOR}</td>
                      <td>
                        {assinatura ? (
                          <Etiqueta {...etiquetaAssinatura(assinatura.situacao)} />
                        ) : (
                          <span className="texto-secundario">Sem assinatura</span>
                        )}
                      </td>
                      <td>{assinatura ? formatarData(assinatura.data_vencimento) : SEM_VALOR}</td>
                      <td>
                        <Link
                          className="botao-secundario botao-pequeno link-botao"
                          to={`/admin/assinantes/${assinante.id_usuario}`}
                        >
                          Detalhes
                        </Link>
                      </td>
                    </tr>
                  );
                })}
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
              Página {dados.pagina} de {totalPaginas} · {dados.total} assinante(s)
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