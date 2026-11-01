import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './estilos/tema.css';
import './estilos/global.css';

// Segue o tema do sistema (claro/escuro), como no app mobile
const escuro = window.matchMedia('(prefers-color-scheme: dark)').matches;
document.documentElement.dataset.tema = escuro ? 'escuro' : 'claro';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);