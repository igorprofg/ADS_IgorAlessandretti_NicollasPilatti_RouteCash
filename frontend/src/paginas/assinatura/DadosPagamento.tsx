import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useCarregar } from '../../hooks/useCarregar';
import {
  buscarDadosPagamento,
  salvarDadosPagamento,
} from '../../servicos/dados-pagamento.servico';
import type { DadosPagamentoUsuario } from '../../tipos/dados-pagamento.tipos';
import { mensagemDeErro } from '../../utilitarios/mensagem-erro';
import '../../estilos/assinaturas.css';
import '../../estilos/planos-admin.css';

interface FormularioProps {
  dados: DadosPagamentoUsuario;
}

function Formulario({ dados }: FormularioProps) {
  const navegar = useNavigate();
  const local = useLocation();
  // Se veio de um plano, volta para ele depois de salvar
  const voltarPara: string = local.state?.voltarPara ?? '/assinatura';

  const [cpfCnpj, setCpfCnpj] = useState(dados.cpf_cnpj ?? '');
  const [celular, setCelular] = useState(dados.celular ?? '');
  const [cep, setCep] = useState(dados.cep ?? '');
  const [logradouro, setLogradouro] = useState(dados.logradouro ?? '');
  const [numero, setNumero] = useState(dados.numero_endereco ?? '');
  const [complemento, setComplemento] = useState(dados.complemento ?? '');
  const [bairro, setBairro] = useState(dados.bairro ?? '');
  const [erro, setErro] = useState('');
  const [enviando, setEnviando] = useState(false);

  async function aoEnviar(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault();
    setErro('');
    setEnviando(true);

    try {
      await salvarDadosPagamento({
        cpf_cnpj: cpfCnpj,
        celular: celular || undefined,
        cep,
        logradouro,
        numero_endereco: numero,
        complemento: complemento || undefined,
        bairro,
      });
      navegar(voltarPara, { replace: true });
    } catch (e) {
      setErro(mensagemDeErro(e, 'Não foi possível salvar os dados'));
      setEnviando(false);
    }
  }

  return (
    <div className="card formulario-plano">
      <h1>Dados para pagamento</h1>
      <p className="texto-secundario">
        Estes dados são enviados ao Asaas para emitir a cobrança da sua assinatura.
      </p>

      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}

      <form className="formulario" onSubmit={aoEnviar}>
        <div className="grupo-campo">
          <label className="rotulo" htmlFor="dp-cpf">
            CPF ou CNPJ
          </label>
          <input
            id="dp-cpf"
            className="campo"
            type="text"
            inputMode="numeric"
            maxLength={18}
            required
            value={cpfCnpj}
            onChange={(e) => setCpfCnpj(e.target.value)}
          />
        </div>

        <div className="grupo-campo">
          <label className="rotulo" htmlFor="dp-celular">
            Celular (com DDD, opcional)
          </label>
          <input
            id="dp-celular"
            className="campo"
            type="text"
            inputMode="tel"
            maxLength={20}
            value={celular}
            onChange={(e) => setCelular(e.target.value)}
          />
        </div>

        <div className="grupo-campo">
          <label className="rotulo" htmlFor="dp-cep">
            CEP
          </label>
          <input
            id="dp-cep"
            className="campo"
            type="text"
            inputMode="numeric"
            maxLength={9}
            required
            value={cep}
            onChange={(e) => setCep(e.target.value)}
          />
        </div>

        <div className="grupo-campo">
          <label className="rotulo" htmlFor="dp-logradouro">
            Logradouro
          </label>
          <input
            id="dp-logradouro"
            className="campo"
            type="text"
            maxLength={150}
            required
            value={logradouro}
            onChange={(e) => setLogradouro(e.target.value)}
          />
        </div>

        <div className="grupo-campo">
          <label className="rotulo" htmlFor="dp-numero">
            Número
          </label>
          <input
            id="dp-numero"
            className="campo"
            type="text"
            maxLength={20}
            required
            value={numero}
            onChange={(e) => setNumero(e.target.value)}
          />
        </div>

        <div className="grupo-campo">
          <label className="rotulo" htmlFor="dp-complemento">
            Complemento (opcional)
          </label>
          <input
            id="dp-complemento"
            className="campo"
            type="text"
            maxLength={100}
            value={complemento}
            onChange={(e) => setComplemento(e.target.value)}
          />
        </div>

        <div className="grupo-campo">
          <label className="rotulo" htmlFor="dp-bairro">
            Bairro
          </label>
          <input
            id="dp-bairro"
            className="campo"
            type="text"
            maxLength={100}
            required
            value={bairro}
            onChange={(e) => setBairro(e.target.value)}
          />
        </div>

        <div className="acoes-formulario">
          <button className="botao" type="submit" disabled={enviando}>
            {enviando ? 'Salvando...' : 'Salvar'}
          </button>
          <Link to={voltarPara} className="botao-secundario link-botao">
            Cancelar
          </Link>
        </div>
      </form>
    </div>
  );
}

// Tela do motorista: /dados-pagamento
export default function DadosPagamento() {
  const { dados, carregando, erro } = useCarregar(buscarDadosPagamento);

  return (
    <section className="pagina">
      {erro && (
        <p className="mensagem-erro" role="alert">
          {erro}
        </p>
      )}
      {carregando && <p className="texto-secundario">Carregando...</p>}
      {/* Só monta o formulário depois que os dados chegam (os campos já nascem preenchidos) */}
      {!carregando && !erro && dados && <Formulario dados={dados} />}
    </section>
  );
}