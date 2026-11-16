import { useState } from 'react';
import { Link } from 'react-router-dom';
import Etiqueta from '../../../componentes/comum/Etiqueta';
import ModalConfirmacao from '../../../componentes/comum/ModalConfirmacao';
import { useCarregar } from '../../../hooks/useCarregar';
import {
  ativarPlano,
  inativarPlano,
  listarPlanosAdmin,
} from '../../../servicos/planos-admin.servico';
import type { PlanoAdmin } from '../../../tipos/planos-admin.tipos';
import { formatarMoeda } from '../../../utilitarios/formatadores';
import { mensagemDeErro } from '../../../utilitarios/mensagem-erro';
import { rotuloPeriodo } from '../../../utilitarios/rotulos';
import '../../../componentes/comum/comum.css';
import '../../../estilos/assinaturas.css';
import '../../../estilos/admin.css';
import '../../../estilos/planos-admin.css';

interface AcaoPlano {
  tipo: 'ativar' | 'inativar';
  plano: PlanoAdmin;
}

// RF16 – Gerenciar Planos: lista (todos, inclusive inativos), criar, editar, ativar e inativar
export default function PlanosAdmin() {
  const { dados: planos, carregando, erro, recarregar } = useCarregar(listarPlanosAdmin);

  const [acao, setAcao] = useState<AcaoPlano | null>(null);
  const [processando, setProcessando] = useState(false);
  const [erroAcao, setErroAcao] = useState('');
  const [sucesso, setSucesso] = useState('');

  async function confirmar() {
    if (!acao) return;
    setProcessando(true);
    setErroAcao('');

    try {
      if (acao.tipo === 'ativar') {
        await ativarPlano(acao.plano.id_plano);
        setSucesso(`Plano "${acao.plano.nome}" ativado.`);
      } else {
        await inativarPlano(acao.plano.id_plano);
        setSucesso(`Plano "${acao.plano.nome}" inativado.`);
      }
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
      <div className="cabecalho-pagina">
        <div>
          <h1>Planos</h1>
          <p className="texto-secundario">Cadastre e mantenha os planos oferecidos aos motoristas.</p>
        </div>
        <Link to="/admin/planos/novo" className="botao link-botao">
          Novo plano
        </Link>
      </div>

      {sucesso && <p className="mensagem-sucesso">{sucesso}</p>}
      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}
      {carregando && !planos && <p className="texto-secundario">Carregando...</p>}

      {planos && planos.length === 0 && (
        <p className="texto-secundario">Nenhum plano cadastrado ainda.</p>
      )}

      {planos && planos.length > 0 && (
        <div className="card">
          <div className="tabela-container">
            <table className="tabela">
              <thead>
                <tr>
                  <th>Nome</th>
                  <th>Valor</th>
                  <th>Cobrança</th>
                  <th>Situação</th>
                  <th>Assinaturas</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {planos.map((plano) => (
                  <tr key={plano.id_plano}>
                    <td>{plano.nome}</td>
                    <td>{formatarMoeda(plano.valor)}</td>
                    <td>{rotuloPeriodo(plano.periodo_cobranca)}</td>
                    <td>
                      <Etiqueta
                        texto={plano.ativo ? 'Ativo' : 'Inativo'}
                        tipo={plano.ativo ? 'positivo' : 'neutro'}
                      />
                    </td>
                    <td>
                      {plano.assinaturas_em_aberto} em aberto · {plano.total_assinaturas} no total
                    </td>
                    <td>
                      <div className="acoes-formulario">
                        <Link
                          className="botao-secundario botao-pequeno link-botao"
                          to={`/admin/planos/${plano.id_plano}/editar`}
                        >
                          Editar
                        </Link>
                        <button
                          className="botao-secundario botao-pequeno"
                          onClick={() =>
                            setAcao({ tipo: plano.ativo ? 'inativar' : 'ativar', plano })
                          }
                        >
                          {plano.ativo ? 'Inativar' : 'Ativar'}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {acao && (
        <ModalConfirmacao
          titulo={acao.tipo === 'ativar' ? 'Ativar plano?' : 'Inativar plano?'}
          textoConfirmar={acao.tipo === 'ativar' ? 'Sim, ativar' : 'Sim, inativar'}
          perigo={acao.tipo === 'inativar'}
          processando={processando}
          erro={erroAcao}
          aoConfirmar={confirmar}
          aoCancelar={() => setAcao(null)}
        >
          <p>
            <strong>{acao.plano.nome}</strong>
          </p>
          <p className="texto-secundario">
            {acao.tipo === 'ativar'
              ? 'O plano volta a aparecer para os motoristas e pode ser contratado.'
              : 'O plano deixa de aparecer para os motoristas e não aceita novas contratações. As assinaturas existentes continuam mantidas.'}
          </p>
        </ModalConfirmacao>
      )}
    </section>
  );
}