import '../../../core/network/dio_client.dart';
import 'sync_item_result.dart';
import 'sync_snapshot.dart';

class SyncRepository {
  final _dio = DioClient.instance;

  Future<List<SyncItemResult>> enviar({
    List<Map<String, dynamic>> ganhos = const [],
    List<Map<String, dynamic>> despesas = const [],
    List<Map<String, dynamic>> jornadas = const [],
    List<Map<String, dynamic>> exclusoes = const [],
  }) async {
    if (ganhos.length > 50 ||
        despesas.length > 50 ||
        jornadas.length > 50 ||
        exclusoes.length > 50) {
      throw Exception('Cada grupo da sincronização aceita no máximo 50 itens.');
    }

    final body = <String, dynamic>{};

    if (ganhos.isNotEmpty) {
      body['ganhos'] = ganhos;
    }

    if (despesas.isNotEmpty) {
      body['despesas'] = despesas;
    }

    if (jornadas.isNotEmpty) {
      body['jornadas'] = jornadas;
    }

    if (exclusoes.isNotEmpty) {
      body['exclusoes'] = exclusoes;
    }

    final response = await _dio.post('/sincronizacao/enviar', data: body);

    final data = Map<String, dynamic>.from(response.data as Map);

    final rawResults = data['resultados'];

    if (rawResults is! List) {
      return [];
    }

    return rawResults
        .whereType<Map>()
        .map((item) => SyncItemResult.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<SyncSnapshot> baixar() async {
    final response = await _dio.get('/sincronizacao/baixar');

    final data = Map<String, dynamic>.from(response.data as Map);

    return SyncSnapshot.fromJson(data);
  }

  Future<SyncItemResult> enviarGanho({
    required String idGanho,
    required String idVeiculo,
    required String idPlataforma,
    required double valor,
    required DateTime data,
    required String? observacao,
    required DateTime atualizadoEm,
  }) async {
    final resultados = await enviar(
      ganhos: [
        {
          'id_ganho': idGanho,
          'id_veiculo': idVeiculo,
          'id_plataforma': idPlataforma,
          'valor': valor,
          'data': _formatDate(data),
          'observacao': _cleanObservation(observacao),
          'atualizado_em': _formatDateTime(atualizadoEm),
        },
      ],
    );

    return _singleResult(resultados, entidade: 'ganho', id: idGanho);
  }

  Future<SyncItemResult> enviarDespesa({
    required String idDespesa,
    required String idVeiculo,
    required String idCategoria,
    required double valor,
    required DateTime data,
    required String? observacao,
    required DateTime atualizadoEm,
  }) async {
    final resultados = await enviar(
      despesas: [
        {
          'id_despesa': idDespesa,
          'id_veiculo': idVeiculo,
          'id_categoria': idCategoria,
          'valor': valor,
          'data': _formatDate(data),
          'observacao': _cleanObservation(observacao),
          'atualizado_em': _formatDateTime(atualizadoEm),
        },
      ],
    );

    return _singleResult(resultados, entidade: 'despesa', id: idDespesa);
  }

  Future<SyncItemResult> enviarJornada({
    required String idJornada,
    required String idVeiculo,
    required DateTime inicio,
    DateTime? fim,
    double? kmRodados,
    required DateTime atualizadoEm,
  }) async {
    final resultados = await enviar(
      jornadas: [
        {
          'id_jornada': idJornada,
          'id_veiculo': idVeiculo,
          'inicio': _formatDateTime(inicio),
          'fim': fim == null ? null : _formatDateTime(fim),
          'km_rodados': kmRodados,
          'atualizado_em': _formatDateTime(atualizadoEm),
        },
      ],
    );

    return _singleResult(resultados, entidade: 'jornada', id: idJornada);
  }

  Future<SyncItemResult> excluir({
    required String entidade,
    required String id,
  }) async {
    if (entidade != 'ganho' && entidade != 'despesa' && entidade != 'jornada') {
      throw Exception('Entidade inválida para exclusão.');
    }

    final resultados = await enviar(
      exclusoes: [
        {'entidade': entidade, 'id': id},
      ],
    );

    return _singleResult(resultados, entidade: entidade, id: id);
  }

  SyncItemResult _singleResult(
    List<SyncItemResult> resultados, {
    required String entidade,
    required String id,
  }) {
    for (final resultado in resultados) {
      if (resultado.entidade == entidade && resultado.id == id) {
        return resultado;
      }
    }

    if (resultados.length == 1) {
      return resultados.first;
    }

    throw Exception('O servidor não retornou o resultado da sincronização.');
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _formatDateTime(DateTime date) {
    return date.toUtc().toIso8601String();
  }

  String? _cleanObservation(String? value) {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) {
      return null;
    }

    return clean;
  }
}
