import {
  Bar,
  BarChart,
  CartesianGrid,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { DiaSerie } from '../../tipos/indicadores.tipos';
import {
  formatarDiaMes,
  formatarEixo,
  formatarMoeda,
} from '../../utilitarios/formatadores';
import { COR_LINHA_EIXO, ESTILO_EIXO, ESTILO_TOOLTIP } from './estilo-grafico';

interface GraficoFaturamentoDespesasProps {
  dias: DiaSerie[];
}

// Barras lado a lado: faturamento (verde de receita) x despesas (vermelho), por dia
export default function GraficoFaturamentoDespesas({
  dias,
}: GraficoFaturamentoDespesasProps) {
  const dados = dias.map((dia) => ({ ...dia, rotulo: formatarDiaMes(dia.data) }));

  return (
    <div className="grafico">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={dados} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
          <CartesianGrid
            stroke={COR_LINHA_EIXO}
            strokeDasharray="3 3"
            vertical={false}
          />
          <XAxis dataKey="rotulo" tick={ESTILO_EIXO} stroke={COR_LINHA_EIXO} />
          <YAxis
            tick={ESTILO_EIXO}
            stroke={COR_LINHA_EIXO}
            tickFormatter={(valor: number) => formatarEixo(valor)}
          />
          <Tooltip
            formatter={(valor) => formatarMoeda(Number(valor))}
            labelFormatter={(rotulo) => `Dia ${String(rotulo)}`}
            contentStyle={ESTILO_TOOLTIP}
            cursor={{ fill: 'var(--cor-destaque-suave)' }}
          />
          <Legend
            formatter={(nome) => (
              <span style={{ color: 'var(--cor-texto)' }}>{nome}</span>
            )}
          />
          <Bar
            dataKey="faturamento"
            name="Faturamento"
            fill="var(--cor-receita)"
            radius={[6, 6, 0, 0]}
          />
          <Bar
            dataKey="despesas"
            name="Despesas"
            fill="var(--cor-despesa)"
            radius={[6, 6, 0, 0]}
          />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}