import {
  CartesianGrid,
  Line,
  LineChart,
  ReferenceLine,
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

interface GraficoLucroAcumuladoProps {
  dias: DiaSerie[];
}

// Linha com a evolução do lucro ao longo do período (o acumulado vem pronto do backend)
export default function GraficoLucroAcumulado({
  dias,
}: GraficoLucroAcumuladoProps) {
  const dados = dias.map((dia) => ({ ...dia, rotulo: formatarDiaMes(dia.data) }));

  return (
    <div className="grafico">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={dados} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
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
            formatter={(valor) => [formatarMoeda(Number(valor)), 'Lucro acumulado']}
            labelFormatter={(rotulo) => `Dia ${String(rotulo)}`}
            contentStyle={ESTILO_TOOLTIP}
          />
          {/* Linha do zero: deixa claro quando o lucro fica negativo */}
          <ReferenceLine
            y={0}
            stroke="var(--cor-texto-secundario)"
            strokeDasharray="4 4"
          />
          <Line
            type="monotone"
            dataKey="lucro_acumulado"
            name="Lucro acumulado"
            stroke="var(--cor-destaque)"
            strokeWidth={3}
            dot={dados.length <= 31}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}