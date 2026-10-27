import 'dart:convert';

class SyncOutboxItem {
  final int? id;
  final String entidade;
  final String registroId;
  final String operacao;
  final String? payloadJson;
  final String estado;
  final String? codigoErro;
  final String? motivoErro;
  final int tentativas;
  final DateTime atualizadoEm;

  const SyncOutboxItem({
    this.id,
    required this.entidade,
    required this.registroId,
    required this.operacao,
    this.payloadJson,
    required this.estado,
    this.codigoErro,
    this.motivoErro,
    required this.tentativas,
    required this.atualizadoEm,
  });

  bool get pendente => estado == 'pendente';

  bool get precisaAtencao =>
      estado == 'atencao';

  bool get exclusao =>
      operacao == 'delete';

  Map<String, dynamic>? get payload {
    final raw = payloadJson;

    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(
        decoded,
      );
    }

    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entidade': entidade,
      'registro_id': registroId,
      'operacao': operacao,
      'payload_json': payloadJson,
      'estado': estado,
      'codigo_erro': codigoErro,
      'motivo_erro': motivoErro,
      'tentativas': tentativas,
      'atualizado_em':
          atualizadoEm.toUtc().toIso8601String(),
    };
  }

  factory SyncOutboxItem.fromMap(
    Map<String, Object?> map,
  ) {
    return SyncOutboxItem(
      id: map['id'] as int?,
      entidade:
          map['entidade'].toString(),
      registroId:
          map['registro_id'].toString(),
      operacao:
          map['operacao'].toString(),
      payloadJson:
          map['payload_json']?.toString(),
      estado:
          map['estado']?.toString() ??
              'pendente',
      codigoErro:
          map['codigo_erro']?.toString(),
      motivoErro:
          map['motivo_erro']?.toString(),
      tentativas:
          (map['tentativas'] as num?)
                  ?.toInt() ??
              0,
      atualizadoEm: DateTime.parse(
        map['atualizado_em'].toString(),
      ),
    );
  }
}
