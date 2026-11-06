import { api } from './api';
import type {
  Indicadores,
  Periodo,
  SerieIndicadores,
} from '../tipos/indicadores.tipos';

// RF09: totais e indicadores do período (os cálculos são feitos no backend)
export async function buscarIndicadores(periodo: Periodo) {
  const { data } = await api.get<Indicadores>('/indicadores', {
    params: { inicio: periodo.inicio, fim: periodo.fim },
  });
  return data;
}

// RF10: série diária (faturamento, despesas, lucro) para os gráficos
export async function buscarSerie(periodo: Periodo) {
  const { data } = await api.get<SerieIndicadores>('/indicadores/serie', {
    params: { inicio: periodo.inicio, fim: periodo.fim },
  });
  return data;
}