class SyncSnapshot {
  final DateTime sincronizadoEm;

  final List<Map<String, dynamic>> veiculos;
  final List<Map<String, dynamic>> plataformas;
  final List<Map<String, dynamic>> categoriasDespesa;
  final List<Map<String, dynamic>> ganhos;
  final List<Map<String, dynamic>> despesas;
  final List<Map<String, dynamic>> jornadas;

  const SyncSnapshot({
    required this.sincronizadoEm,
    required this.veiculos,
    required this.plataformas,
    required this.categoriasDespesa,
    required this.ganhos,
    required this.despesas,
    required this.jornadas,
  });

  factory SyncSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    List<Map<String, dynamic>> mapList(
      dynamic value,
    ) {
      if (value is! List) {
        return [];
      }

      return value
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(
              item,
            ),
          )
          .toList();
    }

    return SyncSnapshot(
      sincronizadoEm: DateTime.parse(
        json['sincronizado_em'].toString(),
      ),
      veiculos: mapList(
        json['veiculos'],
      ),
      plataformas: mapList(
        json['plataformas'],
      ),
      categoriasDespesa: mapList(
        json['categorias_despesa'],
      ),
      ganhos: mapList(
        json['ganhos'],
      ),
      despesas: mapList(
        json['despesas'],
      ),
      jornadas: mapList(
        json['jornadas'],
      ),
    );
  }
}
