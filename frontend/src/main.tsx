import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { AutenticacaoProvedor } from './contextos/AutenticacaoContexto';
import { aplicarTemaInicial } from './utilitarios/tema';
import './estilos/tema.css';
import './estilos/global.css';

// Aplica o tema salvo no localStorage ou o padrão do sistema operacional
aplicarTemaInicial();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <AutenticacaoProvedor>
        <App />
      </AutenticacaoProvedor>
    </BrowserRouter>
  </StrictMode>,
);