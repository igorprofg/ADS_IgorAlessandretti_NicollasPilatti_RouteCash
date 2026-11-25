import { Link } from 'react-router-dom';
import { useCarregar } from '../../hooks/useCarregar';
import { buscarAssinaturaAtual } from '../../servicos/assinaturas.servico';
import './aviso-assinatura.css';

// Aviso no dashboard do motorista quando não há assinatura ativa e válida.
// Leitura continua liberada; só novos lançamentos no aplicativo ficam bloqueados.
export default function AvisoAssinatura() {
  const { dados: atual, carregando, erro } = useCarregar(buscarAssinaturaAtual);

  if (carregando || erro) return null;

  let motivo: string | null = null;
  if (atual === null) {
    motivo = 'Você ainda não tem uma assinatura ativa.';
  } else if (atual.situacao === 'PENDENTE') {
    motivo = 'Sua assinatura está aguardando a confirmação do pagamento.';
  } else if (atual.situacao === 'SUSPENSA') {
    motivo = 'Sua assinatura está suspensa.';
  } else if (atual.vencida) {
    motivo = 'Sua assinatura está vencida.';
  }

  if (motivo === null) return null;

  return (
    <div className="aviso-assinatura" role="status">
      <p>
        <strong>{motivo}</strong> Novos lançamentos no aplicativo estão bloqueados, mas você
        continua podendo consultar os seus dados.
      </p>
      <Link
        to={atual ? '/assinatura' : '/planos'}
        className="botao-secundario link-botao"
      >
        {atual ? 'Ver minha assinatura' : 'Ver planos'}
      </Link>
    </div>
  );
}