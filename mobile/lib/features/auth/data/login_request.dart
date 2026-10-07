class LoginRequest {
  final String email;
  final String senha;

  const LoginRequest({required this.email, required this.senha});

  Map<String, dynamic> toJson() {
    return {'email': email, 'senha': senha};
  }
}
