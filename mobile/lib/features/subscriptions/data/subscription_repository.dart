import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class SubscriptionRepository {
  final Dio _dio = DioClient.instance;

  Future<Map<String, dynamic>?> buscarAtual() async {
    try {
      final response = await _dio
          .get<dynamic>(
            '/assinaturas/atual',
            options: Options(
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (response.data == null) return null;
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
