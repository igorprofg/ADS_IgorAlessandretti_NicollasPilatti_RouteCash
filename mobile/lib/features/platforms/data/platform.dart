class Platform {
  final String idPlataforma;
  final String idUsuario;
  final String nome;
  final bool ativa;
  final bool padrao;

  const Platform({
    required this.idPlataforma,
    required this.idUsuario,
    required this.nome,
    required this.ativa,
    required this.padrao,
  });

  factory Platform.fromJson(Map<String, dynamic> json) {
    return Platform(
      idPlataforma: json['id_plataforma'].toString(),
      idUsuario: json['id_usuario'].toString(),
      nome: json['nome'].toString(),
      ativa: json['ativa'] == true,
      padrao: json['padrao'] == true,
    );
  }
}
