import { api } from './api';
import type { IndicadoresAdmin } from '../tipos/indicadores-admin.tipos';
import type { Periodo } from '../tipos/indicadores.tipos';

// HU55 e HU56: sem período = todos os registros
export async function buscarIndicadoresAdmin(periodo: Periodo | null) {
  const { data } = await api.get<IndicadoresAdmin>('/admin/indicadores', {
    params: {
      inicio: periodo?.inicio,
      fim: periodo?.fim,
    },
  });
  return data;
}