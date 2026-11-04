export type TipoUsuario = 'MOTORISTA' | 'ADMINISTRADOR';

export interface Usuario {
  id_usuario: string;
  nome: string;
  email: string;
  tipo_usuario: TipoUsuario;
  status_conta?: string;
  aceite_termos_em?: string;
  data_cadastro?: string;
  data_atualizacao?: string;
}

// Corpo de POST /usuarios
export interface CadastroDados {
  nome: string;
  email: string;
  senha: string;
  confirmarSenha: string;
  aceiteTermos: boolean;
}

// Resposta de POST /autenticacao/login
export interface LoginResposta {
  access_token: string;
  usuario: Pick<Usuario, 'id_usuario' | 'nome' | 'email' | 'tipo_usuario'>;
}