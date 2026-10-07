import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'create_user_request.dart';

class UserRepository {
  final Dio _dio;

  UserRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _dio.get('/usuarios/me');

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        final message = data['message'];

        if (message is String) {
          throw Exception(message);
        }
      }

      throw Exception('Não foi possível carregar o perfil.');
    }
  }

  Future<void> createUser(CreateUserRequest request) async {
    try {
      await _dio.post('/usuarios', data: request.toJson());
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        final message = data['message'];

        if (message is String) {
          throw Exception(message);
        }

        if (message is List && message.isNotEmpty) {
          throw Exception(message.first.toString());
        }
      }

      throw Exception('Não foi possível criar o usuário.');
    }
  }
}
