class CreateExpenseRequest {
  final String idVeiculo;
  final String idCategoria;
  final double valor;
  final DateTime data;

  const CreateExpenseRequest({
    required this.idVeiculo,
    required this.idCategoria,
    required this.valor,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'id_veiculo': idVeiculo,
      'id_categoria': idCategoria,
      'valor': valor,
      'data': DateTime.utc(data.year, data.month, data.day).toIso8601String(),
    };
  }
}
