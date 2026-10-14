import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'platform.dart';

class PlatformRepository {
  final Dio _dio;

  PlatformRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<List<Platform>> findAll() async {
    try {
      final response = await _dio.get('/plataformas');

      final lista = response.data as List;

      return lista
          .map((item) => Platform.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível carregar as plataformas.'),
      );
    }
  }

  Future<Platform> create(String nome) async {
    try {
      final response = await _dio.post('/plataformas', data: {'nome': nome});

      return Platform.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível cadastrar a plataforma.'),
      );
    }
  }

  Future<Platform> update(String id, String nome) async {
    try {
      final response = await _dio.patch(
        '/plataformas/$id',
        data: {'nome': nome},
      );

      return Platform.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível atualizar a plataforma.'),
      );
    }
  }

  Future<Platform> toggleActive(String id) async {
    try {
      final response = await _dio.patch('/plataformas/$id/alternar-ativa');

      return Platform.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(
          e,
          'Não foi possível alterar a situação da plataforma.',
        ),
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
