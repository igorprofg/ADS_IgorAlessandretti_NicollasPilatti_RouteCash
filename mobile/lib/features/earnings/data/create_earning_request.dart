class CreateEarningRequest {
  final String idVeiculo;
  final String idPlataforma;
  final double valor;
  final DateTime data;

  const CreateEarningRequest({
    required this.idVeiculo,
    required this.idPlataforma,
    required this.valor,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'id_veiculo': idVeiculo,
      'id_plataforma': idPlataforma,
      'valor': valor,
      'data': DateTime.utc(data.year, data.month, data.day).toIso8601String(),
    };
  }
}
