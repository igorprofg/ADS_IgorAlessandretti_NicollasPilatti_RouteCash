class StartJourneyRequest {
  final String idVeiculo;
  final DateTime? inicio;

  const StartJourneyRequest({required this.idVeiculo, this.inicio});

  Map<String, dynamic> toJson() {
    return {
      'id_veiculo': idVeiculo,

      if (inicio != null) 'inicio': inicio!.toUtc().toIso8601String(),
    };
  }
}
