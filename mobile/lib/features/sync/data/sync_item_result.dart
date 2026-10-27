class SyncItemResult {
  final String entidade;
  final String? id;
  final String status;
  final String? acao;
  final String? codigo;
  final String? motivo;

  const SyncItemResult({
    required this.entidade,
    required this.status,
    this.id,
    this.acao,
    this.codigo,
    this.motivo,
  });

  bool get sucesso {
    return status == 'ok' || status == 'ignorado';
  }

  bool get precisaTentarNovamente {
    return status == 'erro' && codigo == 'ERRO_INTERNO';
  }

  bool get precisaAtencao {
    return status == 'erro' &&
        (codigo == 'VALIDACAO' ||
            codigo == 'NAO_ENCONTRADO' ||
            codigo == 'CONFLITO');
  }

  factory SyncItemResult.fromJson(Map<String, dynamic> json) {
    return SyncItemResult(
      entidade: json['entidade']?.toString() ?? '',
      id: json['id']?.toString(),
      status: json['status']?.toString() ?? 'erro',
      acao: json['acao']?.toString(),
      codigo: json['codigo']?.toString(),
      motivo: json['motivo']?.toString(),
    );
  }
}
