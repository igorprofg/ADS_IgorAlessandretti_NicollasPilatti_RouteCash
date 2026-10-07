import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import 'login_request.dart';
import 'login_response.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        '/autenticacao/login',
        data: request.toJson(),
      );

      final loginResponse = LoginResponse.fromJson(
        Map<String, dynamic>.from(response.data),
      );

      await SecureStorage.saveToken(loginResponse.accessToken);

      return loginResponse;
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

      throw Exception('Não foi possível realizar o login.');
    }
  }
}
