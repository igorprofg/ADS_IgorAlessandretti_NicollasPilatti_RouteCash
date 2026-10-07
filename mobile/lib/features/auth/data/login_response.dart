class LoginResponse {
  final String accessToken;
  final UsuarioLogado usuario;

  const LoginResponse({required this.accessToken, required this.usuario});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String,
      usuario: UsuarioLogado.fromJson(json['usuario'] as Map<String, dynamic>),
    );
  }
}

class UsuarioLogado {
  final String idUsuario;
  final String nome;
  final String email;
  final String tipoUsuario;

  const UsuarioLogado({
    required this.idUsuario,
    required this.nome,
    required this.email,
    required this.tipoUsuario,
  });

  factory UsuarioLogado.fromJson(Map<String, dynamic> json) {
    return UsuarioLogado(
      idUsuario: json['id_usuario'] as String,
      nome: json['nome'] as String,
      email: json['email'] as String,
      tipoUsuario: json['tipo_usuario'] as String,
    );
  }
}
