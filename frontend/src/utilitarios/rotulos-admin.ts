import type { StatusConta } from '../tipos/admin.tipos';
import type { DadosEtiqueta } from './rotulos';

// Etiqueta da situação do assinante (conta): ativo, suspenso ou bloqueado
export function etiquetaConta(status: StatusConta): DadosEtiqueta {
  switch (status) {
    case 'ATIVO':
      return { texto: 'Ativo', tipo: 'positivo' };
    case 'SUSPENSO':
      return { texto: 'Suspenso', tipo: 'neutro' };
    default:
      return { texto: 'Bloqueado', tipo: 'negativo' };
  }
}