class UpdateVehicleRequest {
  final String? marca;
  final String? modelo;
  final int? ano;
  final String? combustivel;
  final double? consumoMedio;
  final String? placa;

  const UpdateVehicleRequest({
    this.marca,
    this.modelo,
    this.ano,
    this.combustivel,
    this.consumoMedio,
    this.placa,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (marca != null) {
      json['marca'] = marca;
    }

    if (modelo != null) {
      json['modelo'] = modelo;
    }

    if (ano != null) {
      json['ano'] = ano;
    }

    if (combustivel != null) {
      json['combustivel'] = combustivel;
    }

    if (consumoMedio != null) {
      json['consumo_medio'] = consumoMedio;
    }

    if (placa != null && placa!.trim().isNotEmpty) {
      json['placa'] = placa!.trim();
    }

    return json;
  }
}
