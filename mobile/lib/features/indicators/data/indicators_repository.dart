import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'financial_indicators.dart';

class IndicatorsRepository {
  final Dio _dio;

  IndicatorsRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<FinancialIndicators> calculate({
    DateTime? inicio,
    DateTime? fim,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};

      if (inicio != null && fim != null) {
        queryParameters['inicio'] = _formatDate(inicio);

        queryParameters['fim'] = _formatDate(fim);
      }

      final response = await _dio.get(
        '/indicadores',
        queryParameters: queryParameters,
      );

      return FinancialIndicators.fromJson(
        Map<String, dynamic>.from(response.data),
      );
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível carregar os indicadores.'),
      );
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
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
