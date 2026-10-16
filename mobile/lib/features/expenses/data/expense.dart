class Expense {
  final String idDespesa;
  final String idVeiculo;
  final String idCategoria;
  final double valor;
  final DateTime data;

  final String? veiculoMarca;
  final String? veiculoModelo;
  final String? categoriaNome;

  const Expense({
    required this.idDespesa,
    required this.idVeiculo,
    required this.idCategoria,
    required this.valor,
    required this.data,
    this.veiculoMarca,
    this.veiculoModelo,
    this.categoriaNome,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    final veiculo = json['veiculo'];
    final categoria = json['categoria'];

    return Expense(
      idDespesa: json['id_despesa'].toString(),
      idVeiculo: json['id_veiculo'].toString(),
      idCategoria: json['id_categoria'].toString(),
      valor: double.parse(json['valor'].toString()),
      data: DateTime.parse(json['data'].toString()),
      veiculoMarca: veiculo is Map ? veiculo['marca']?.toString() : null,
      veiculoModelo: veiculo is Map ? veiculo['modelo']?.toString() : null,
      categoriaNome: categoria is Map ? categoria['nome']?.toString() : null,
    );
  }
}
