import { useState } from 'react';
import { useAutenticacao } from '../../contextos/AutenticacaoContexto';
import { useDashboard } from '../../hooks/useDashboard';
import CartaoIndicador from '../../componentes/dashboard/CartaoIndicador';
import CartaoResumo from '../../componentes/dashboard/CartaoResumo';
import FiltroPeriodo from '../../componentes/dashboard/FiltroPeriodo';
import GraficoFaturamentoDespesas from '../../componentes/dashboard/GraficoFaturamentoDespesas';
import GraficoLucroAcumulado from '../../componentes/dashboard/GraficoLucroAcumulado';
import {
  formatarData,
  formatarHoras,
  formatarKm,
  formatarMoeda,
} from '../../utilitarios/formatadores';
import { periodoDoPreset } from '../../utilitarios/periodos';
import type { PresetPeriodo } from '../../utilitarios/periodos';
import type { Periodo } from '../../tipos/indicadores.tipos';
import './dashboard.css';

// RF10 – Visualizar Indicadores Financeiros.
// Os valores vêm calculados do backend (/indicadores e /indicadores/serie);
// aqui só se escolhe o período e se apresenta o resultado.
export default function Dashboard() {
  const { usuario } = useAutenticacao();

  // Padrão = dia atual (HU30). Para abrir em "7 dias", troque 'hoje' por '7dias' nas duas linhas.
  const [preset, setPreset] = useState<PresetPeriodo>('hoje');
  const [periodo, setPeriodo] = useState<Periodo>(() => periodoDoPreset('hoje'));

  const { indicadores, serie, carregando, erro } = useDashboard(periodo);

  function alterarPeriodo(novoPreset: PresetPeriodo, novoPeriodo: Periodo) {
    setPreset(novoPreset);
    setPeriodo(novoPeriodo);
  }

  const primeiroNome = usuario?.nome.split(' ')[0];
  const semLancamentos =
    indicadores !== null &&
    indicadores.faturamento === 0 &&
    indicadores.despesas === 0;

  return (
    <section className="dashboard">
      <div>
        <h1>Dashboard</h1>
        <p className="texto-secundario">
          Olá, {primeiroNome}. Veja como está a sua rentabilidade.
        </p>
      </div>

      <FiltroPeriodo preset={preset} periodo={periodo} aoAlterar={alterarPeriodo} />

      <p className="texto-secundario dashboard-periodo">
        Período: {formatarData(periodo.inicio)} a {formatarData(periodo.fim)}
        {carregando && ' · atualizando...'}
      </p>

      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}

      {indicadores && (
        <>
          <CartaoResumo indicadores={indicadores} />

          {semLancamentos && (
            <p className="texto-secundario dashboard-vazio">
              Nenhum ganho ou despesa lançado neste período.
            </p>
          )}

          <div className="grade-indicadores">
            <CartaoIndicador
              rotulo="Horas trabalhadas"
              valor={formatarHoras(indicadores.horas_trabalhadas)}
            />
            <CartaoIndicador
              rotulo="Km rodados"
              valor={formatarKm(indicadores.km_rodados)}
            />
            <CartaoIndicador
              rotulo="Ganho por hora"
              valor={formatarMoeda(indicadores.ganho_por_hora)}
            />
            <CartaoIndicador
              rotulo="Ganho por km"
              valor={formatarMoeda(indicadores.ganho_por_km)}
            />
            <CartaoIndicador
              rotulo="Custo por km"
              valor={formatarMoeda(indicadores.custo_por_km)}
            />
          </div>
        </>
      )}

      {serie && (
        <>
          <div>
            <h2>Médias por dia</h2>
            <div className="grade-indicadores">
              <CartaoIndicador
                rotulo="Faturamento"
                valor={formatarMoeda(serie.medias_diarias.faturamento)}
              />
              <CartaoIndicador
                rotulo="Despesas"
                valor={formatarMoeda(serie.medias_diarias.despesas)}
              />
              <CartaoIndicador
                rotulo="Lucro líquido"
                valor={formatarMoeda(serie.medias_diarias.lucro_liquido)}
              />
            </div>
          </div>

          <div className="grade-graficos">
            <section className="card">
              <h2>Faturamento × despesas por dia</h2>
              <GraficoFaturamentoDespesas dias={serie.dias} />
            </section>

            <section className="card">
              <h2>Evolução do lucro</h2>
              <GraficoLucroAcumulado dias={serie.dias} />
            </section>
          </div>
        </>
      )}
    </section>
  );
}