import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'create_earning_request.dart';
import 'earning.dart';
import 'update_earning_request.dart';

class EarningRepository {
  final Dio _dio;

  EarningRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<List<Earning>> findAll() async {
    try {
      final response = await _dio.get('/ganhos');

      final lista = response.data as List;

      return lista
          .map((item) => Earning.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível carregar os ganhos.'),
      );
    }
  }

  Future<Earning> findOne(String id) async {
    try {
      final response = await _dio.get('/ganhos/$id');

      return Earning.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível carregar o ganho.'),
      );
    }
  }

  Future<void> create(CreateEarningRequest request) async {
    try {
      await _dio.post('/ganhos', data: request.toJson());
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível registrar o ganho.'),
      );
    }
  }

  Future<void> update(String id, UpdateEarningRequest request) async {
    try {
      await _dio.patch('/ganhos/$id', data: request.toJson());
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível atualizar o ganho.'),
      );
    }
  }

  Future<String> delete(String id) async {
    try {
      final response = await _dio.delete('/ganhos/$id');

      return response.data['mensagem']?.toString() ??
          'Ganho removido com sucesso.';
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e, 'Não foi possível remover o ganho.'));
    }
  }

  Future<void> duplicate(String id, {DateTime? data}) async {
    try {
      final body = <String, dynamic>{};

      if (data != null) {
        body['data'] = DateTime.utc(
          data.year,
          data.month,
          data.day,
        ).toIso8601String();
      }

      await _dio.post('/ganhos/$id/duplicar', data: body);
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível duplicar o ganho.'),
      );
    }
  }

  String _getErrorMessage(DioException e, String fallback) {
    final data = e.response?.data;

    if (data is Map<String, dynamic>) {
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
