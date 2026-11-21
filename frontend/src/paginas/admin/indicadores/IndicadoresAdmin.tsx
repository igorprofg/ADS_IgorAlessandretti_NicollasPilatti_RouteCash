import { useCallback, useState } from 'react';
import type { FormEvent } from 'react';
import GraficoBarras from '../../../componentes/admin/GraficoBarras';
import type { DadoBarra } from '../../../componentes/admin/GraficoBarras';
import CartaoIndicador from '../../../componentes/dashboard/CartaoIndicador';
import { useCarregar } from '../../../hooks/useCarregar';
import { buscarIndicadoresAdmin } from '../../../servicos/indicadores-admin.servico';
import type { Periodo } from '../../../tipos/indicadores.tipos';
import { formatarData, formatarMoeda } from '../../../utilitarios/formatadores';
import { periodoDoPreset, validarPeriodo } from '../../../utilitarios/periodos';
import '../../dashboard/dashboard.css';
import '../../../estilos/assinaturas.css';
import '../../../estilos/admin.css';

type Modo = 'tudo' | 'mes' | '30dias' | 'livre';

function texto(data: Date) {
  const mm = String(data.getMonth() + 1).padStart(2, '0');
  const dd = String(data.getDate()).padStart(2, '0');
  return `${data.getFullYear()}-${mm}-${dd}`;
}

function ultimosDias(quantidade: number): Periodo {
  const hoje = new Date();
  const inicio = new Date(hoje);
  inicio.setDate(hoje.getDate() - (quantidade - 1));
  return { inicio: texto(inicio), fim: texto(hoje) };
}

// "2026-11" -> "11/26"
const rotuloMes = (mes: string) => `${mes.slice(5)}/${mes.slice(2, 4)}`;

// RF19 – indicadores administrativos (HU55) com filtro por período (HU56)
export default function IndicadoresAdmin() {
  const [modo, setModo] = useState<Modo>('tudo');
  const [periodo, setPeriodo] = useState<Periodo | null>(null); // null = todo o período
  const [inicio, setInicio] = useState(() => periodoDoPreset('mes').inicio);
  const [fim, setFim] = useState(() => periodoDoPreset('mes').fim);
  const [erroFiltro, setErroFiltro] = useState('');

  const buscar = useCallback(() => buscarIndicadoresAdmin(periodo), [periodo]);
  const { dados, carregando, erro } = useCarregar(buscar);

  function escolher(novoModo: Modo, novoPeriodo: Periodo | null) {
    setErroFiltro('');
    setModo(novoModo);
    setPeriodo(novoPeriodo);
    if (novoPeriodo) {
      setInicio(novoPeriodo.inicio);
      setFim(novoPeriodo.fim);
    }
  }

  function aplicarPersonalizado(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault();
    const candidato = { inicio, fim };
    const mensagem = validarPeriodo(candidato);
    if (mensagem) {
      setErroFiltro(mensagem);
      return;
    }
    setErroFiltro('');
    setPeriodo(candidato);
  }

  const assinaturasGrafico: DadoBarra[] = dados
    ? [
        { rotulo: 'Aguardando', valor: dados.assinaturas.pendentes, cor: 'var(--cor-destaque)' },
        { rotulo: 'Ativas', valor: dados.assinaturas.ativas, cor: 'var(--cor-receita)' },
        { rotulo: 'Suspensas', valor: dados.assinaturas.suspensas, cor: 'var(--cor-texto-secundario)' },
        { rotulo: 'Canceladas', valor: dados.assinaturas.canceladas, cor: 'var(--cor-despesa)' },
      ]
    : [];

  const pagamentosGrafico: DadoBarra[] = dados
    ? [
        { rotulo: 'Pendentes', valor: dados.pagamentos.pendentes.quantidade, cor: 'var(--cor-destaque)' },
        { rotulo: 'Pagos', valor: dados.pagamentos.pagos.quantidade, cor: 'var(--cor-receita)' },
        { rotulo: 'Vencidos', valor: dados.pagamentos.vencidos.quantidade, cor: 'var(--cor-despesa)' },
        { rotulo: 'Cancelados', valor: dados.pagamentos.cancelados.quantidade, cor: 'var(--cor-texto-secundario)' },
      ]
    : [];

  const receitaGrafico: DadoBarra[] = dados
    ? dados.receita_mensal.map((item) => ({
        rotulo: rotuloMes(item.mes),
        valor: item.receita,
        cor: 'var(--cor-receita)',
      }))
    : [];

  return (
    <section className="dashboard">
      <div>
        <h1>Indicadores</h1>
        <p className="texto-secundario">Visão geral de usuários, assinaturas e pagamentos.</p>
      </div>

      <div>
        <div className="filtro-periodo" role="group" aria-label="Período">
          <button
            type="button"
            className={`chip${modo === 'tudo' ? ' chip--ativo' : ''}`}
            onClick={() => escolher('tudo', null)}
          >
            Todo o período
          </button>
          <button
            type="button"
            className={`chip${modo === 'mes' ? ' chip--ativo' : ''}`}
            onClick={() => escolher('mes', periodoDoPreset('mes'))}
          >
            Este mês
          </button>
          <button
            type="button"
            className={`chip${modo === '30dias' ? ' chip--ativo' : ''}`}
            onClick={() => escolher('30dias', ultimosDias(30))}
          >
            Últimos 30 dias
          </button>
          <button
            type="button"
            className={`chip${modo === 'livre' ? ' chip--ativo' : ''}`}
            onClick={() => setModo('livre')}
          >
            Personalizado
          </button>
        </div>

        {modo === 'livre' && (
          <form className="filtro-datas" onSubmit={aplicarPersonalizado}>
            <div className="grupo-campo">
              <label className="rotulo" htmlFor="ind-inicio">
                De
              </label>
              <input
                id="ind-inicio"
                className="campo"
                type="date"
                value={inicio}
                onChange={(e) => setInicio(e.target.value)}
              />
            </div>
            <div className="grupo-campo">
              <label className="rotulo" htmlFor="ind-fim">
                Até
              </label>
              <input
                id="ind-fim"
                className="campo"
                type="date"
                value={fim}
                onChange={(e) => setFim(e.target.value)}
              />
            </div>
            <button className="botao" type="submit">
              Aplicar
            </button>
          </form>
        )}

        {erroFiltro && (
          <p className="mensagem-erro" role="alert">
            {erroFiltro}
          </p>
        )}
      </div>

      <p className="texto-secundario dashboard-periodo">
        {periodo
          ? `Período: ${formatarData(periodo.inicio)} a ${formatarData(periodo.fim)}`
          : 'Todo o período'}
        {carregando && ' · atualizando...'}
      </p>

      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}

      {dados && (
        <>
          <section className="cartao-resumo">
            <p className="cartao-resumo-rotulo">Receita registrada</p>
            <p className="cartao-resumo-valor">{formatarMoeda(dados.receita_registrada)}</p>
            <div className="cartao-resumo-linha">
              <div>
                <span className="cartao-resumo-rotulo">Pagamentos pagos</span>
                <strong>{dados.pagamentos.pagos.quantidade}</strong>
              </div>
              <div>
                <span className="cartao-resumo-rotulo">Usuários cadastrados</span>
                <strong>{dados.usuarios.total}</strong>
              </div>
            </div>
          </section>

          <div>
            <h2>Assinaturas</h2>
            <div className="grade-indicadores">
              <CartaoIndicador rotulo="Ativas" valor={String(dados.assinaturas.ativas)} />
              <CartaoIndicador rotulo="Suspensas" valor={String(dados.assinaturas.suspensas)} />
              <CartaoIndicador rotulo="Canceladas" valor={String(dados.assinaturas.canceladas)} />
              <CartaoIndicador rotulo="Aguardando pagamento" valor={String(dados.assinaturas.pendentes)} />
            </div>
          </div>

          <div>
            <h2>Pagamentos</h2>
            <div className="grade-indicadores">
              <CartaoIndicador
                rotulo="Pendentes"
                valor={`${dados.pagamentos.pendentes.quantidade} · ${formatarMoeda(dados.pagamentos.pendentes.valor)}`}
              />
              <CartaoIndicador
                rotulo="Vencidos"
                valor={`${dados.pagamentos.vencidos.quantidade} · ${formatarMoeda(dados.pagamentos.vencidos.valor)}`}
              />
            </div>
          </div>

          <div className="grade-graficos">
            <section className="card">
              <h2>Assinaturas por situação</h2>
              <GraficoBarras dados={assinaturasGrafico} nomeSerie="Assinaturas" />
            </section>

            <section className="card">
              <h2>Pagamentos por situação</h2>
              <GraficoBarras dados={pagamentosGrafico} nomeSerie="Pagamentos" />
            </section>

            <section className="card">
              <h2>Receita por mês</h2>
              {receitaGrafico.length === 0 ? (
                <p className="texto-secundario">Nenhum pagamento pago no período.</p>
              ) : (
                <GraficoBarras dados={receitaGrafico} nomeSerie="Receita" moeda />
              )}
            </section>
          </div>
        </>
      )}
    </section>
  );
}