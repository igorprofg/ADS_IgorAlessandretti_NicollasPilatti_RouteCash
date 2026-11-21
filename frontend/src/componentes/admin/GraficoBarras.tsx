import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { formatarEixo, formatarMoeda } from '../../utilitarios/formatadores';
import { COR_LINHA_EIXO, ESTILO_EIXO, ESTILO_TOOLTIP } from '../dashboard/estilo-grafico';

export interface DadoBarra {
  rotulo: string;
  valor: number;
  cor?: string; // cor própria da barra (usa as variáveis do tema)
}

interface GraficoBarrasProps {
  dados: DadoBarra[];
  nomeSerie: string;
  moeda?: boolean; // formata o valor como R$
}

// Gráfico de barras simples, reaproveitado nos gráficos administrativos
export default function GraficoBarras({
  dados,
  nomeSerie,
  moeda = false,
}: GraficoBarrasProps) {
  return (
    <div className="grafico">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={dados} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
          <CartesianGrid stroke={COR_LINHA_EIXO} strokeDasharray="3 3" vertical={false} />
          <XAxis dataKey="rotulo" tick={ESTILO_EIXO} stroke={COR_LINHA_EIXO} />
          <YAxis
            tick={ESTILO_EIXO}
            stroke={COR_LINHA_EIXO}
            allowDecimals={moeda}
            tickFormatter={(valor: number) => formatarEixo(valor)}
          />
          <Tooltip
            formatter={(valor) => [
              moeda ? formatarMoeda(Number(valor)) : String(valor),
              nomeSerie,
            ]}
            contentStyle={ESTILO_TOOLTIP}
            cursor={{ fill: 'var(--cor-destaque-suave)' }}
          />
          <Bar dataKey="valor" name={nomeSerie} fill="var(--cor-destaque)" radius={[6, 6, 0, 0]}>
            {dados.map((dado) => (
              <Cell key={dado.rotulo} fill={dado.cor ?? 'var(--cor-destaque)'} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}