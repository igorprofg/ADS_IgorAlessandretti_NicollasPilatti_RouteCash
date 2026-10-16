class ExpenseCategory {
  final String idCategoria;
  final String nome;
  final String? idUsuario;

  const ExpenseCategory({
    required this.idCategoria,
    required this.nome,
    this.idUsuario,
  });

  bool get padrao => idUsuario == null;

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      idCategoria: json['id_categoria'].toString(),
      nome: json['nome'].toString(),
      idUsuario: json['id_usuario']?.toString(),
    );
  }
}
