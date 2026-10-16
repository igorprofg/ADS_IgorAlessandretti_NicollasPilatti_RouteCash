class UpdateEarningRequest {
  final String? idVeiculo;
  final String? idPlataforma;
  final double? valor;
  final DateTime? data;

  const UpdateEarningRequest({
    this.idVeiculo,
    this.idPlataforma,
    this.valor,
    this.data,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (idVeiculo != null) {
      json['id_veiculo'] = idVeiculo;
    }

    if (idPlataforma != null) {
      json['id_plataforma'] = idPlataforma;
    }

    if (valor != null) {
      json['valor'] = valor;
    }

    if (data != null) {
      json['data'] = DateTime.utc(
        data!.year,
        data!.month,
        data!.day,
      ).toIso8601String();
    }

    return json;
  }
}
