class Vehicle {
  final String idVeiculo;
  final String idUsuario;
  final String marca;
  final String modelo;
  final int ano;
  final String combustivel;
  final double consumoMedio;
  final String? placa;
  final bool principal;
  final bool ativo;

  const Vehicle({
    required this.idVeiculo,
    required this.idUsuario,
    required this.marca,
    required this.modelo,
    required this.ano,
    required this.combustivel,
    required this.consumoMedio,
    required this.placa,
    required this.principal,
    required this.ativo,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      idVeiculo: json['id_veiculo'].toString(),
      idUsuario: json['id_usuario'].toString(),
      marca: json['marca'].toString(),
      modelo: json['modelo'].toString(),
      ano: int.parse(json['ano'].toString()),
      combustivel: json['combustivel'].toString(),
      consumoMedio: double.parse(json['consumo_medio'].toString()),
      placa: json['placa']?.toString(),
      principal: json['principal'] == true,
      ativo: json['ativo'] == true,
    );
  }
}
