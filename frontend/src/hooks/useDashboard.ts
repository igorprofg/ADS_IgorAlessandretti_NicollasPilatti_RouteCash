import { useEffect, useState } from 'react';
import {
  buscarIndicadores,
  buscarSerie,
} from '../servicos/indicadores.servico';
import { mensagemDeErro } from '../utilitarios/mensagem-erro';
import type {
  Indicadores,
  Periodo,
  SerieIndicadores,
} from '../tipos/indicadores.tipos';

// Busca os indicadores e a série do período; busca de novo quando o período muda
export function useDashboard(periodo: Periodo) {
  const { inicio, fim } = periodo;

  const [indicadores, setIndicadores] = useState<Indicadores | null>(null);
  const [serie, setSerie] = useState<SerieIndicadores | null>(null);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState('');

  useEffect(() => {
    let cancelado = false; // evita gravar resposta antiga se o período mudou no meio
    setCarregando(true);
    setErro('');

    Promise.all([
      buscarIndicadores({ inicio, fim }),
      buscarSerie({ inicio, fim }),
    ])
      .then(([resultadoIndicadores, resultadoSerie]) => {
        if (cancelado) return;
        setIndicadores(resultadoIndicadores);
        setSerie(resultadoSerie);
      })
      .catch((e) => {
        if (cancelado) return;
        setErro(mensagemDeErro(e, 'Não foi possível carregar os indicadores'));
      })
      .finally(() => {
        if (!cancelado) setCarregando(false);
      });

    return () => {
      cancelado = true;
    };
  }, [inicio, fim]);

  return { indicadores, serie, carregando, erro };
}