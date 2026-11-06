import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { useAutenticacao } from '../../contextos/AutenticacaoContexto';
import { cadastrarUsuario } from '../../servicos/autenticacao.servico';
import { mensagemDeErro } from '../../utilitarios/mensagem-erro';

export default function Cadastro() {
  const { usuario } = useAutenticacao();
  const navegar = useNavigate();

  const [nome, setNome] = useState('');
  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');
  const [confirmarSenha, setConfirmarSenha] = useState('');
  const [aceiteTermos, setAceiteTermos] = useState(false);
  const [erro, setErro] = useState('');
  const [enviando, setEnviando] = useState(false);

  if (usuario) {
    return <Navigate to="/dashboard" replace />;
  }

  async function aoEnviar(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault();
    setErro('');

    // Mesmas regras da HU03 (o servidor valida de novo)
    if (senha.length < 6) {
      setErro('A senha deve ter no mínimo 6 caracteres');
      return;
    }
    if (senha !== confirmarSenha) {
      setErro('As senhas não coincidem');
      return;
    }
    if (!aceiteTermos) {
      setErro('É necessário aceitar os Termos de Uso');
      return;
    }

    setEnviando(true);
    try {
      await cadastrarUsuario({
        nome: nome.trim(),
        email: email.trim(),
        senha,
        confirmarSenha,
        aceiteTermos,
      });
      navegar('/login', { replace: true, state: { cadastroOk: true } });
    } catch (e) {
      setErro(mensagemDeErro(e, 'Não foi possível criar a conta'));
      setEnviando(false);
    }
  }

  return (
    <main className="pagina-centralizada">
      <section className="card">
  <div
    style={{
      borderRadius: '12px',
      padding: '8px',
      marginBottom: '20px',
    }}
  >
    <img
      src="/logo-routecash.png"
      alt="RouteCash"
      style={{
        display: 'block',
        width: '100%',
        maxWidth: '320px',
        height: 'auto',
        margin: '0 auto',
      }}
    />
  </div>

  <h1>Criar conta</h1>
  <p className="texto-secundario">
    Cadastre-se para controlar seus ganhos e despesas.
  </p>

        {erro && (
          <p className="mensagem-erro" role="alert">
            {erro}
          </p>
        )}

        <form className="formulario" onSubmit={aoEnviar}>
          <div className="grupo-campo">
            <label className="rotulo" htmlFor="nome">
              Nome
            </label>
            <input
              id="nome"
              className="campo"
              type="text"
              autoComplete="name"
              maxLength={100}
              required
              value={nome}
              onChange={(e) => setNome(e.target.value)}
            />
          </div>

          <div className="grupo-campo">
            <label className="rotulo" htmlFor="email">
              E-mail
            </label>
            <input
              id="email"
              className="campo"
              type="email"
              autoComplete="email"
              maxLength={150}
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>

          <div className="grupo-campo">
            <label className="rotulo" htmlFor="senha">
              Senha
            </label>
            <input
              id="senha"
              className="campo"
              type="password"
              autoComplete="new-password"
              required
              value={senha}
              onChange={(e) => setSenha(e.target.value)}
            />
          </div>

          <div className="grupo-campo">
            <label className="rotulo" htmlFor="confirmarSenha">
              Confirmar senha
            </label>
            <input
              id="confirmarSenha"
              className="campo"
              type="password"
              autoComplete="new-password"
              required
              value={confirmarSenha}
              onChange={(e) => setConfirmarSenha(e.target.value)}
            />
          </div>

          <label className="opcao-caixa">
            <input
              type="checkbox"
              checked={aceiteTermos}
              onChange={(e) => setAceiteTermos(e.target.checked)}
            />
            <span>Li e aceito os Termos de Uso</span>
          </label>

          <button className="botao botao-largo" type="submit" disabled={enviando}>
            {enviando ? 'Criando conta...' : 'Criar conta'}
          </button>
        </form>

        <p className="texto-centro texto-secundario">
          Já tem conta? <Link to="/login">Entrar</Link>
        </p>
      </section>
    </main>
  );
}