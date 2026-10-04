class CreateUserRequest {
  final String nome;
  final String email;
  final String senha;
  final String confirmarSenha;
  final bool aceiteTermos;

  const CreateUserRequest({
    required this.nome,
    required this.email,
    required this.senha,
    required this.confirmarSenha,
    required this.aceiteTermos,
  });

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'email': email,
      'senha': senha,
      'confirmarSenha': confirmarSenha,
      'aceiteTermos': aceiteTermos,
    };
  }
}
