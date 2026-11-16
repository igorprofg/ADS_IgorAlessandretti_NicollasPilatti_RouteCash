import { useCallback, useState } from 'react';
import type { FormEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useCarregar } from '../../../hooks/useCarregar';
import {
  atualizarPlano,
  buscarPlanoAdmin,
  criarPlano,
} from '../../../servicos/planos-admin.servico';
import type { PlanoAdmin } from '../../../tipos/planos-admin.tipos';
import { mensagemDeErro } from '../../../utilitarios/mensagem-erro';
import { rotuloPeriodo } from '../../../utilitarios/rotulos';
import '../../../estilos/assinaturas.css';
import '../../../estilos/planos-admin.css';

const PERIODOS = ['MENSAL', 'TRIMESTRAL', 'SEMESTRAL', 'ANUAL'];

interface FormularioProps {
  plano: PlanoAdmin | null; // null = novo plano
}

function Formulario({ plano }: FormularioProps) {
  const navegar = useNavigate();

  const [nome, setNome] = useState(plano?.nome ?? '');
  const [valor, setValor] = useState(plano ? String(plano.valor) : '');
  const [periodo, setPeriodo] = useState(plano?.periodo_cobranca.toUpperCase() ?? 'MENSAL');
  const [beneficios, setBeneficios] = useState(plano?.beneficios ?? '');
  const [erro, setErro] = useState('');
  const [enviando, setEnviando] = useState(false);

  // Com assinaturas, o período não pode mudar (os vencimentos delas já foram calculados com ele)
  const periodoTravado = plano !== null && plano.total_assinaturas > 0;

  async function aoEnviar(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault();
    setErro('');

    // Mesmas regras da HU45 (o servidor valida de novo)
    const valorNumero = Number(valor.replace(',', '.'));
    if (!nome.trim()) {
      setErro('O nome do plano é obrigatório');
      return;
    }
    if (!Number.isFinite(valorNumero) || valorNumero <= 0) {
      setErro('O valor deve ser maior que zero');
      return;
    }
    if (!beneficios.trim()) {
      setErro('Informe as características e benefícios do plano');
      return;
    }

    const dados = {
      nome: nome.trim(),
      valor: valorNumero,
      periodo_cobranca: periodo,
      beneficios: beneficios.trim(),
    };

    setEnviando(true);
    try {
      if (plano) {
        await atualizarPlano(plano.id_plano, dados);
      } else {
        await criarPlano(dados);
      }
      navegar('/admin/planos');
    } catch (e) {
      setErro(mensagemDeErro(e, 'Não foi possível salvar o plano'));
      setEnviando(false);
    }
  }

  return (
    <div className="card formulario-plano">
      <h1>{plano ? 'Editar plano' : 'Novo plano'}</h1>

      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}

      <form className="formulario" onSubmit={aoEnviar}>
        <div className="grupo-campo">
          <label className="rotulo" htmlFor="plano-nome">
            Nome
          </label>
          <input
            id="plano-nome"
            className="campo"
            type="text"
            maxLength={60}
            required
            value={nome}
            onChange={(e) => setNome(e.target.value)}
          />
        </div>

        <div className="grupo-campo">
          <label className="rotulo" htmlFor="plano-valor">
            Valor (R$)
          </label>
          <input
            id="plano-valor"
            className="campo"
            type="number"
            step="0.01"
            min="0.01"
            required
            value={valor}
            onChange={(e) => setValor(e.target.value)}
          />
          {plano && plano.total_assinaturas > 0 && (
            <p className="dica-campo">
              A alteração vale para as próximas cobranças. As assinaturas existentes são mantidas.
            </p>
          )}
        </div>

        <div className="grupo-campo">
          <label className="rotulo" htmlFor="plano-periodo">
            Período de cobrança
          </label>
          <select
            id="plano-periodo"
            className="campo"
            value={periodo}
            disabled={periodoTravado}
            onChange={(e) => setPeriodo(e.target.value)}
          >
            {PERIODOS.map((p) => (
              <option key={p} value={p}>
                {rotuloPeriodo(p)}
              </option>
            ))}
          </select>
          {periodoTravado && (
            <p className="dica-campo">
              Este plano já tem assinaturas, então o período não pode ser alterado. Para mudar o
              período, crie um novo plano e inative este.
            </p>
          )}
        </div>

        <div className="grupo-campo">
          <label className="rotulo" htmlFor="plano-beneficios">
            Benefícios (um por linha)
          </label>
          <textarea
            id="plano-beneficios"
            className="campo"
            maxLength={2000}
            required
            value={beneficios}
            onChange={(e) => setBeneficios(e.target.value)}
          />
        </div>

        <div className="acoes-formulario">
          <button className="botao" type="submit" disabled={enviando}>
            {enviando ? 'Salvando...' : 'Salvar'}
          </button>
          <Link to="/admin/planos" className="botao-secundario link-botao">
            Cancelar
          </Link>
        </div>
      </form>
    </div>
  );
}

// Serve para criar (/admin/planos/novo) e editar (/admin/planos/:id/editar)
export default function FormularioPlano() {
  const { id } = useParams();

  const buscar = useCallback(
    (): Promise<PlanoAdmin | null> => (id ? buscarPlanoAdmin(id) : Promise.resolve(null)),
    [id],
  );
  const { dados: existente, carregando, erro } = useCarregar(buscar);

  return (
    <section className="pagina">
      <Link to="/admin/planos" className="voltar">
        ← Voltar aos planos
      </Link>

      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}
      {carregando && <p className="texto-secundario">Carregando...</p>}

      {/* Só monta o formulário quando os dados já chegaram (assim os campos já nascem preenchidos) */}
      {!carregando && !erro && (id ? existente : true) && (
        <Formulario key={existente?.id_plano ?? 'novo'} plano={existente} />
      )}
    </section>
  );
}