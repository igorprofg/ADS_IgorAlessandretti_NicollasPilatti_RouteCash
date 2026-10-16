import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'create_expense_request.dart';
import 'expense.dart';
import 'update_expense_request.dart';

class ExpenseRepository {
  final Dio _dio;

  ExpenseRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<List<Expense>> findAll() async {
    try {
      final response = await _dio.get('/despesas');

      final lista = response.data as List;

      return lista
          .map((item) => Expense.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível carregar as despesas.'),
      );
    }
  }

  Future<Expense> findOne(String id) async {
    try {
      final response = await _dio.get('/despesas/$id');

      return Expense.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível carregar a despesa.'),
      );
    }
  }

  Future<void> create(CreateExpenseRequest request) async {
    try {
      await _dio.post('/despesas', data: request.toJson());
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível registrar a despesa.'),
      );
    }
  }

  Future<void> update(String id, UpdateExpenseRequest request) async {
    try {
      await _dio.patch('/despesas/$id', data: request.toJson());
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível atualizar a despesa.'),
      );
    }
  }

  Future<String> delete(String id) async {
    try {
      final response = await _dio.delete('/despesas/$id');

      return response.data['mensagem']?.toString() ??
          'Despesa removida com sucesso.';
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível remover a despesa.'),
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
