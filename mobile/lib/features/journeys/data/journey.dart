class Journey {
  final String idJornada;
  final String? idUsuario;
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
    this.idUsuario,
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
    final nome = '${veiculoMarca ?? ''} ${veiculoModelo ?? ''}'.trim();

    return nome.isEmpty ? 'Veículo' : nome;
  }

  Duration get duracao {
    final fimEfetivo = fim ?? DateTime.now();

    if (fimEfetivo.isBefore(inicio)) {
      return Duration.zero;
    }

    return fimEfetivo.difference(inicio);
  }

  int get duracaoTotalMinutos {
    if (duracaoMinutos != null) {
      return duracaoMinutos!;
    }

    return duracao.inMinutes;
  }

  factory Journey.fromJson(Map<String, dynamic> json) {
    final veiculo = json['veiculo'];

    String? marca;
    String? modelo;
    String? placa;

    if (veiculo is Map) {
      marca = veiculo['marca']?.toString();
      modelo = veiculo['modelo']?.toString();
      placa = veiculo['placa']?.toString();
    }

    final inicio = DateTime.parse(json['inicio'].toString());

    final fimRaw = json['fim'];

    final fim = fimRaw == null ? null : DateTime.parse(fimRaw.toString());

    final duracaoRaw = json['duracao_minutos'];

    return Journey(
      idJornada: json['id_jornada'].toString(),
      idUsuario: json['id_usuario']?.toString(),
      idVeiculo: json['id_veiculo'].toString(),
      inicio: inicio,
      fim: fim,
      kmRodados: (json['km_rodados'] as num?)?.toDouble(),
      duracaoMinutos: (duracaoRaw as num?)?.toInt(),
      veiculoMarca: json['veiculo_marca']?.toString() ?? marca,
      veiculoModelo: json['veiculo_modelo']?.toString() ?? modelo,
      veiculoPlaca: json['veiculo_placa']?.toString() ?? placa,
    );
  }
}
