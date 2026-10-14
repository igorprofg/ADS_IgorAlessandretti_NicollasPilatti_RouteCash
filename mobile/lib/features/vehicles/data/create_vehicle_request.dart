class CreateVehicleRequest {
  final String marca;
  final String modelo;
  final int ano;
  final String combustivel;
  final double consumoMedio;
  final String? placa;

  const CreateVehicleRequest({
    required this.marca,
    required this.modelo,
    required this.ano,
    required this.combustivel,
    required this.consumoMedio,
    this.placa,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'marca': marca,
      'modelo': modelo,
      'ano': ano,
      'combustivel': combustivel,
      'consumo_medio': consumoMedio,
    };

    if (placa != null && placa!.trim().isNotEmpty) {
      json['placa'] = placa!.trim();
    }

    return json;
  }
}
