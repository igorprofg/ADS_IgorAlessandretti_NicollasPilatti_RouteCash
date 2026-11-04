import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link, Navigate, useLocation } from 'react-router-dom';
import { useAutenticacao } from '../../contextos/AutenticacaoContexto';
import { mensagemDeErro } from '../../utilitarios/mensagem-erro';

export default function Login() {
  const { usuario, entrar } = useAutenticacao();
  const local = useLocation();

  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');
  const [erro, setErro] = useState('');
  const [enviando, setEnviando] = useState(false);

  const destino: string = local.state?.de ?? '/dashboard';
  const cadastroOk = Boolean(local.state?.cadastroOk);

  // Já está logado (ou acabou de entrar): vai direto para o destino
  if (usuario) {
    return <Navigate to={destino} replace />;
  }

  async function aoEnviar(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault();
    setErro('');
    setEnviando(true);

    try {
      await entrar(email.trim(), senha);
      // O redirecionamento acontece sozinho: o usuário passa a existir no contexto
    } catch (e) {
      setErro(mensagemDeErro(e, 'Não foi possível entrar'));
      setEnviando(false);
    }
  }

  return (
    <main className="pagina-centralizada">
      <section className="card">
        <h1>RouteCash</h1>
        <p className="texto-secundario">
          Entre na sua conta para acompanhar suas finanças.
        </p>

        {cadastroOk && (
          <p className="mensagem-sucesso">
            Conta criada! Entre com seu e-mail e senha.
          </p>
        )}
        {erro && (
          <p className="mensagem-erro" role="alert">
            {erro}
          </p>
        )}

        <form className="formulario" onSubmit={aoEnviar}>
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
              autoComplete="current-password"
              required
              value={senha}
              onChange={(e) => setSenha(e.target.value)}
            />
          </div>

          <button className="botao botao-largo" type="submit" disabled={enviando}>
            {enviando ? 'Entrando...' : 'Entrar'}
          </button>
        </form>

        <p className="texto-centro texto-secundario">
          Ainda não tem conta? <Link to="/cadastro">Cadastre-se</Link>
        </p>
      </section>
    </main>
  );
}