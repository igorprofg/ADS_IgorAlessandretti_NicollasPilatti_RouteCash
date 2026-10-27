class Earning {
  final String idGanho;
  final String idVeiculo;
  final String idPlataforma;
  final double valor;
  final DateTime data;

  final String? veiculoMarca;
  final String? veiculoModelo;
  final String? plataformaNome;
  final String? observacao;

  const Earning({
    required this.idGanho,
    required this.idVeiculo,
    required this.idPlataforma,
    required this.valor,
    required this.data,
    this.veiculoMarca,
    this.veiculoModelo,
    this.plataformaNome,
    this.observacao,
  });

  factory Earning.fromJson(Map<String, dynamic> json) {
    final veiculo = json['veiculo'];
    final plataforma = json['plataforma'];

    return Earning(
      idGanho: json['id_ganho'].toString(),
      idVeiculo: json['id_veiculo'].toString(),
      idPlataforma: json['id_plataforma'].toString(),
      valor: double.parse(json['valor'].toString()),
      data: DateTime.parse(json['data'].toString()),
      veiculoMarca: veiculo is Map ? veiculo['marca']?.toString() : null,
      veiculoModelo: veiculo is Map ? veiculo['modelo']?.toString() : null,
      plataformaNome: plataforma is Map ? plataforma['nome']?.toString() : null,
      observacao: json['observacao']?.toString(),
    );
  }
}
