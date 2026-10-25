class UpdateJourneyRequest {
  final DateTime? inicio;
  final DateTime? fim;

  const UpdateJourneyRequest({this.inicio, this.fim});

  Map<String, dynamic> toJson() {
    return {
      if (inicio != null) 'inicio': inicio!.toUtc().toIso8601String(),

      if (fim != null) 'fim': fim!.toUtc().toIso8601String(),
    };
  }
}
