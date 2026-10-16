class UpdateExpenseRequest {
  final String? idVeiculo;
  final String? idCategoria;
  final double? valor;
  final DateTime? data;

  const UpdateExpenseRequest({
    this.idVeiculo,
    this.idCategoria,
    this.valor,
    this.data,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (idVeiculo != null) {
      json['id_veiculo'] = idVeiculo;
    }

    if (idCategoria != null) {
      json['id_categoria'] = idCategoria;
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
