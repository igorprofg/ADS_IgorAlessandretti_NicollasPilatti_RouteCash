class Journey {
  final String idJornada;
  final String idUsuario;
  final String idVeiculo;

  final DateTime inicio;
  final DateTime? fim;

  final double? kmRodados;
  final int? duracaoMinutos;

  final String? veiculoMarca;
  final String? veiculoModelo;
  final String? veiculoPlaca;

  const Journey({
    required this.idJornada,
    required this.idUsuario,
    required this.idVeiculo,
    required this.inicio,
    this.fim,
    this.kmRodados,
    this.duracaoMinutos,
    this.veiculoMarca,
    this.veiculoModelo,
    this.veiculoPlaca,
  });

  bool get emAndamento => fim == null;

  String get veiculoNome {
    final nome = [
      veiculoMarca,
      veiculoModelo,
    ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' ');

    return nome.isEmpty ? 'Veículo' : nome;
  }

  factory Journey.fromJson(Map<String, dynamic> json) {
    final veiculo = json['veiculo'];

    Map<String, dynamic>? veiculoJson;

    if (veiculo is Map) {
      veiculoJson = Map<String, dynamic>.from(veiculo);
    }

    return Journey(
      idJornada: json['id_jornada'].toString(),
      idUsuario: json['id_usuario']?.toString() ?? '',
      idVeiculo: json['id_veiculo'].toString(),

      inicio: DateTime.parse(json['inicio'].toString()),

      fim: json['fim'] != null ? DateTime.parse(json['fim'].toString()) : null,

      kmRodados: _toDouble(json['km_rodados']),

      duracaoMinutos: _toInt(json['duracao_minutos']),

      veiculoMarca: veiculoJson?['marca']?.toString(),

      veiculoModelo: veiculoJson?['modelo']?.toString(),

      veiculoPlaca: veiculoJson?['placa']?.toString(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.round();
    }

    return int.tryParse(value.toString());
  }
}
