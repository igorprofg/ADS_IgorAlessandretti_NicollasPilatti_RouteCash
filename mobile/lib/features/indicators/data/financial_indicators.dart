class FinancialIndicators {
  final DateTime inicio;
  final DateTime fim;

  final double faturamento;
  final double despesas;
  final double lucroLiquido;

  final double horasTrabalhadas;
  final double kmRodados;

  final double? ganhoPorHora;
  final double? ganhoPorKm;
  final double? custoPorKm;

  const FinancialIndicators({
    required this.inicio,
    required this.fim,
    required this.faturamento,
    required this.despesas,
    required this.lucroLiquido,
    required this.horasTrabalhadas,
    required this.kmRodados,
    this.ganhoPorHora,
    this.ganhoPorKm,
    this.custoPorKm,
  });

  factory FinancialIndicators.fromJson(Map<String, dynamic> json) {
    final periodo = Map<String, dynamic>.from(json['periodo'] as Map);

    return FinancialIndicators(
      inicio: DateTime.parse(periodo['inicio'].toString()),
      fim: DateTime.parse(periodo['fim'].toString()),
      faturamento: _toDouble(json['faturamento']),
      despesas: _toDouble(json['despesas']),
      lucroLiquido: _toDouble(json['lucro_liquido']),
      horasTrabalhadas: _toDouble(json['horas_trabalhadas']),
      kmRodados: _toDouble(json['km_rodados']),
      ganhoPorHora: _toNullableDouble(json['ganho_por_hora']),
      ganhoPorKm: _toNullableDouble(json['ganho_por_km']),
      custoPorKm: _toNullableDouble(json['custo_por_km']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  static double? _toNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }
}
