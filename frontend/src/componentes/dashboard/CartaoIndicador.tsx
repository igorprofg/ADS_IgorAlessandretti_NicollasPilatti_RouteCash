interface CartaoIndicadorProps {
  rotulo: string;
  valor: string;
}

export default function CartaoIndicador({ rotulo, valor }: CartaoIndicadorProps) {
  return (
    <div className="card cartao-indicador">
      <p className="cartao-indicador-rotulo">{rotulo}</p>
      <p className="cartao-indicador-valor">{valor}</p>
    </div>
  );
}