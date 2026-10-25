import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'journey.dart';
import 'start_journey_request.dart';
import 'update_journey_request.dart';

class JourneyRepository {
  final Dio _dio;

  JourneyRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<Journey> start(StartJourneyRequest request) async {
    try {
      final response = await _dio.post(
        '/jornadas/iniciar',
        data: request.toJson(),
      );

      return Journey.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível iniciar a jornada.'),
      );
    }
  }

  Future<List<Journey>> findAll() async {
    try {
      final response = await _dio.get('/jornadas');

      final lista = response.data as List;

      return lista
          .map((item) => Journey.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível carregar as jornadas.'),
      );
    }
  }

  Future<Journey?> findInProgress() async {
    try {
      final response = await _dio.get('/jornadas/em-andamento');

      return Journey.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      // Não possuir jornada em andamento é uma
      // situação normal, não um erro para o app.
      if (e.response?.statusCode == 404) {
        return null;
      }

      throw Exception(
        _getErrorMessage(
          e,
          'Não foi possível verificar a jornada em andamento.',
        ),
      );
    }
  }

  Future<Journey> findOne(String id) async {
    try {
      final response = await _dio.get('/jornadas/$id');

      return Journey.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível carregar a jornada.'),
      );
    }
  }

  Future<Journey> finish(String id, {DateTime? fim}) async {
    try {
      final data = <String, dynamic>{};

      if (fim != null) {
        data['fim'] = fim.toUtc().toIso8601String();
      }

      final response = await _dio.patch('/jornadas/$id/finalizar', data: data);

      return Journey.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível finalizar a jornada.'),
      );
    }
  }

  Future<Journey> update(String id, UpdateJourneyRequest request) async {
    try {
      final response = await _dio.patch(
        '/jornadas/$id',
        data: request.toJson(),
      );

      return Journey.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível atualizar a jornada.'),
      );
    }
  }

  // =============================
  // QUILOMETRAGEM
  // =============================

  Future<void> registerMileage({
    required String journeyId,
    required double km,
  }) async {
    try {
      await _dio.post(
        '/quilometragem',
        data: {'id_jornada': journeyId, 'km_rodados': km},
      );
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível registrar a quilometragem.'),
      );
    }
  }

  Future<void> updateMileage({
    required String journeyId,
    required double km,
  }) async {
    try {
      await _dio.patch('/quilometragem/$journeyId', data: {'km_rodados': km});
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível atualizar a quilometragem.'),
      );
    }
  }

  Future<String> deleteMileage(String journeyId) async {
    try {
      final response = await _dio.delete('/quilometragem/$journeyId');

      if (response.data is Map) {
        return response.data['mensagem']?.toString() ??
            'Quilometragem removida com sucesso.';
      }

      return 'Quilometragem removida com sucesso.';
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível remover a quilometragem.'),
      );
    }
  }

  String _getErrorMessage(DioException e, String fallback) {
    final data = e.response?.data;

    if (data is Map) {
      final message = data['message'];

      if (message is String) {
        return message;
      }

      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
    }

    return fallback;
  }
}
