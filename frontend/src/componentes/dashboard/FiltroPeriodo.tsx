import { useState } from 'react';
import type { Periodo } from '../../tipos/indicadores.tipos';
import { periodoDoPreset, validarPeriodo } from '../../utilitarios/periodos';
import type { PresetPeriodo } from '../../utilitarios/periodos';

interface FiltroPeriodoProps {
  preset: PresetPeriodo;
  periodo: Periodo;
  aoAlterar: (preset: PresetPeriodo, periodo: Periodo) => void;
}

const OPCOES: { preset: Exclude<PresetPeriodo, 'livre'>; rotulo: string }[] = [
  { preset: 'hoje', rotulo: 'Hoje' },
  { preset: '7dias', rotulo: '7 dias' },
  { preset: 'mes', rotulo: 'Mês' },
];

export default function FiltroPeriodo({
  preset,
  periodo,
  aoAlterar,
}: FiltroPeriodoProps) {
  // Datas digitadas no "Personalizado" (só valem depois de clicar em Aplicar)
  const [inicio, setInicio] = useState(periodo.inicio);
  const [fim, setFim] = useState(periodo.fim);
  const [erro, setErro] = useState('');

  function escolherPreset(escolhido: Exclude<PresetPeriodo, 'livre'>) {
    const novo = periodoDoPreset(escolhido);
    setErro('');
    setInicio(novo.inicio);
    setFim(novo.fim);
    aoAlterar(escolhido, novo);
  }

  function aplicarPersonalizado() {
    const candidato = { inicio, fim };
    const mensagem = validarPeriodo(candidato);
    if (mensagem) {
      setErro(mensagem);
      return;
    }
    setErro('');
    aoAlterar('livre', candidato);
  }

  return (
    <div>
      <div className="filtro-periodo" role="group" aria-label="Período">
        {OPCOES.map((opcao) => (
          <button
            key={opcao.preset}
            type="button"
            className={`chip${preset === opcao.preset ? ' chip--ativo' : ''}`}
            onClick={() => escolherPreset(opcao.preset)}
          >
            {opcao.rotulo}
          </button>
        ))}
        <button
          type="button"
          className={`chip${preset === 'livre' ? ' chip--ativo' : ''}`}
          onClick={() => aoAlterar('livre', periodo)}
        >
          Personalizado
        </button>
      </div>

      {preset === 'livre' && (
        <div className="filtro-datas">
          <div className="grupo-campo">
            <label className="rotulo" htmlFor="data-inicio">
              De
            </label>
            <input
              id="data-inicio"
              className="campo"
              type="date"
              value={inicio}
              onChange={(e) => setInicio(e.target.value)}
            />
          </div>

          <div className="grupo-campo">
            <label className="rotulo" htmlFor="data-fim">
              Até
            </label>
            <input
              id="data-fim"
              className="campo"
              type="date"
              value={fim}
              onChange={(e) => setFim(e.target.value)}
            />
          </div>

          <button type="button" className="botao" onClick={aplicarPersonalizado}>
            Aplicar
          </button>
        </div>
      )}

      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}
    </div>
  );
}