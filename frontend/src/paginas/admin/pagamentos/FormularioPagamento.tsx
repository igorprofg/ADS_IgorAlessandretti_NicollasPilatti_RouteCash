import { useState } from 'react';
import type { FormEvent, KeyboardEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { listarAssinaturasAdmin } from '../../../servicos/assinaturas-admin.servico';
import { registrarPagamento } from '../../../servicos/pagamentos-admin.servico';
import type { AssinaturaAdmin } from '../../../tipos/assinaturas-admin.tipos';
import type { SituacaoPagamento } from '../../../tipos/assinaturas.tipos';
import { mensagemDeErro } from '../../../utilitarios/mensagem-erro';
import { periodoDoPreset } from '../../../utilitarios/periodos';
import { etiquetaSituacao } from '../../../utilitarios/rotulos-assinaturas';
import { OPCOES_SITUACAO_PAGAMENTO } from '../../../utilitarios/rotulos-pagamentos';
import '../../../estilos/assinaturas.css';
import '../../../estilos/planos-admin.css';

// HU52: registrar um pagamento (manual) vinculado a uma assinatura
export default function FormularioPagamento() {
  const navegar = useNavigate();

  // Escolha da assinatura (pesquisa por usuário ou plano)
  const [busca, setBusca] = useState('');
  const [resultados, setResultados] = useState<AssinaturaAdmin[] | null>(null);
  const [buscando, setBuscando] = useState(false);
  const [idAssinatura, setIdAssinatura] = useState('');

  const [valor, setValor] = useState('');
  const [vencimento, setVencimento] = useState('');
  const [situacao, setSituacao] = useState<SituacaoPagamento>('PENDENTE');
  const [dataPagamento, setDataPagamento] = useState(() => periodoDoPreset('hoje').inicio);

  const [erro, setErro] = useState('');
  const [enviando, setEnviando] = useState(false);

  async function buscarAssinaturas() {
    setBuscando(true);
    setErro('');
    try {
      const pagina = await listarAssinaturasAdmin({
        busca: busca.trim(),
        situacao: '',
        pagina: 1,
      });
      // Assinaturas contratadas pelo Asaas têm os pagamentos gerenciados pelo gateway
      setResultados(pagina.itens.filter((a) => a.origem !== 'ASAAS'));
      setIdAssinatura('');
    } catch (e) {
      setErro(mensagemDeErro(e, 'Não foi possível buscar as assinaturas'));
    } finally {
      setBuscando(false);
    }
  }

  // Enter no campo de busca pesquisa (e não envia o formulário)
  function aoTeclarNaBusca(evento: KeyboardEvent<HTMLInputElement>) {
    if (evento.key === 'Enter') {
      evento.preventDefault();
      void buscarAssinaturas();
    }
  }

  // Ao escolher a assinatura, sugere o valor do plano
  function escolherAssinatura(id: string) {
    setIdAssinatura(id);
    const escolhida = resultados?.find((a) => a.id_assinatura === id);
    if (escolhida) setValor(String(escolhida.plano.valor));
  }

  async function aoEnviar(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault();
    setErro('');

    // Mesmas regras da HU52 (o servidor valida de novo)
    const valorNumero = Number(valor.replace(',', '.'));
    if (!idAssinatura) {
      setErro('Escolha a assinatura do pagamento');
      return;
    }
    if (!Number.isFinite(valorNumero) || valorNumero <= 0) {
      setErro('O valor deve ser maior que zero');
      return;
    }
    if (!vencimento) {
      setErro('Informe a data de vencimento');
      return;
    }
    if (situacao === 'PAGO' && !dataPagamento) {
      setErro('Informe a data do pagamento');
      return;
    }

    setEnviando(true);
    try {
      await registrarPagamento({
        id_assinatura: idAssinatura,
        valor: valorNumero,
        data_vencimento: vencimento,
        situacao,
        data_pagamento: situacao === 'PAGO' ? dataPagamento : undefined,
      });
      navegar('/admin/pagamentos');
    } catch (e) {
      setErro(mensagemDeErro(e, 'Não foi possível registrar o pagamento'));
      setEnviando(false);
    }
  }

  return (
    <section className="pagina">
      <Link to="/admin/pagamentos" className="voltar">
        ← Voltar aos pagamentos
      </Link>

      <div className="card formulario-plano">
        <h1>Registrar pagamento</h1>

        {erro && (
          <p className="mensagem-erro" role="alert">
            {erro}
          </p>
        )}

        <form className="formulario" onSubmit={aoEnviar}>
          <div className="grupo-campo">
            <label className="rotulo" htmlFor="pag-busca">
              Assinante ou plano
            </label>
            <input
              id="pag-busca"
              className="campo"
              type="text"
              maxLength={150}
              placeholder="Nome, e-mail ou plano"
              value={busca}
              onChange={(e) => setBusca(e.target.value)}
              onKeyDown={aoTeclarNaBusca}
            />
            <div className="acoes-formulario">
              <button
                className="botao-secundario"
                type="button"
                onClick={buscarAssinaturas}
                disabled={buscando}
              >
                {buscando ? 'Buscando...' : 'Buscar assinaturas'}
              </button>
            </div>
          </div>

          {resultados && resultados.length === 0 && (
            <p className="dica-campo">
              Nenhuma assinatura manual encontrada. Os pagamentos de assinaturas contratadas pelo
              Asaas são gerenciados pelo gateway.
            </p>
          )}

          {resultados && resultados.length > 0 && (
            <div className="grupo-campo">
              <label className="rotulo" htmlFor="pag-assinatura">
                Assinatura
              </label>
              <select
                id="pag-assinatura"
                className="campo"
                value={idAssinatura}
                onChange={(e) => escolherAssinatura(e.target.value)}
              >
                <option value="">Selecione...</option>
                {resultados.map((a) => (
                  <option key={a.id_assinatura} value={a.id_assinatura}>
                    {a.usuario.nome} · {a.plano.nome} · {etiquetaSituacao(a.situacao).texto}
                  </option>
                ))}
              </select>
            </div>
          )}

          <div className="grupo-campo">
            <label className="rotulo" htmlFor="pag-valor">
              Valor (R$)
            </label>
            <input
              id="pag-valor"
              className="campo"
              type="number"
              step="0.01"
              min="0.01"
              required
              value={valor}
              onChange={(e) => setValor(e.target.value)}
            />
          </div>

          <div className="grupo-campo">
            <label className="rotulo" htmlFor="pag-vencimento">
              Data de vencimento
            </label>
            <input
              id="pag-vencimento"
              className="campo"
              type="date"
              required
              value={vencimento}
              onChange={(e) => setVencimento(e.target.value)}
            />
          </div>

          <div className="grupo-campo">
            <label className="rotulo" htmlFor="pag-situacao">
              Situação
            </label>
            <select
              id="pag-situacao"
              className="campo"
              value={situacao}
              onChange={(e) => setSituacao(e.target.value as SituacaoPagamento)}
            >
              {OPCOES_SITUACAO_PAGAMENTO.map((opcao) => (
                <option key={opcao.valor} value={opcao.valor}>
                  {opcao.rotulo}
                </option>
              ))}
            </select>
          </div>

          {situacao === 'PAGO' && (
            <div className="grupo-campo">
              <label className="rotulo" htmlFor="pag-data-pagamento">
                Data do pagamento
              </label>
              <input
                id="pag-data-pagamento"
                className="campo"
                type="date"
                max={periodoDoPreset('hoje').inicio}
                value={dataPagamento}
                onChange={(e) => setDataPagamento(e.target.value)}
              />
            </div>
          )}

          <div className="acoes-formulario">
            <button className="botao" type="submit" disabled={enviando}>
              {enviando ? 'Salvando...' : 'Registrar'}
            </button>
            <Link to="/admin/pagamentos" className="botao-secundario link-botao">
              Cancelar
            </Link>
          </div>
        </form>
      </div>
    </section>
  );
}