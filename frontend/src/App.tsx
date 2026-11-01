// Tela provisória, só para confirmar que o setup e o tema estão funcionando.
// Será substituída pelas rotas (login, cadastro, dashboard).
export default function App() {
  return (
    <main className="pagina-centralizada">
      <section className="card">
        <h1>RouteCash</h1>
        <p className="texto-secundario">
          Retaguarda web: configuração inicial concluída.
        </p>
        <p>
          <span className="receita">+ R$ 150,00</span>{' '}
          <span className="despesa">- R$ 35,00</span>
        </p>
        <input className="campo" placeholder="Campo de texto" />
        <p />
        <button className="botao">Botão primário</button>
      </section>
    </main>
  );
}