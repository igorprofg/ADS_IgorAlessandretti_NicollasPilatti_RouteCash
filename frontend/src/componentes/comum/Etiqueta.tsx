import type { TipoEtiqueta } from '../../utilitarios/rotulos';
import './comum.css';

interface EtiquetaProps {
  texto: string;
  tipo: TipoEtiqueta;
}

// "Selo" colorido para mostrar uma situação (ativa, paga, vencida...)
export default function Etiqueta({ texto, tipo }: EtiquetaProps) {
  return <span className={`etiqueta etiqueta--${tipo}`}>{texto}</span>;
}