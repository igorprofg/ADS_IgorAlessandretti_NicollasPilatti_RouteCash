import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'expense_category.dart';

class ExpenseCategoryRepository {
  final Dio _dio;

  ExpenseCategoryRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<List<ExpenseCategory>> findAll() async {
    try {
      final response = await _dio.get('/categorias-despesa');

      final lista = response.data as List;

      return lista
          .map(
            (item) => ExpenseCategory.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível carregar as categorias.'),
      );
    }
  }

  Future<ExpenseCategory> create(String nome) async {
    try {
      final response = await _dio.post(
        '/categorias-despesa',
        data: {'nome': nome},
      );

      return ExpenseCategory.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível criar a categoria.'),
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
