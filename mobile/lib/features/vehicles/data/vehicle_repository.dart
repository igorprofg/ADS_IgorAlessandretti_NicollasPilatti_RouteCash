import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'create_vehicle_request.dart';
import 'update_vehicle_request.dart';
import 'vehicle.dart';

class VehicleRepository {
  final Dio _dio;

  VehicleRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<List<Vehicle>> findAll() async {
    try {
      final response = await _dio.get('/veiculos');

      final lista = response.data as List;

      return lista
          .map((item) => Vehicle.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível carregar os veículos.'),
      );
    }
  }

  Future<List<Vehicle>> findInactive() async {
    try {
      final response = await _dio.get('/veiculos/inativos');

      final lista = response.data as List;

      return lista
          .map((item) => Vehicle.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível carregar os veículos inativos.'),
      );
    }
  }

  Future<Vehicle> create(CreateVehicleRequest request) async {
    try {
      final response = await _dio.post('/veiculos', data: request.toJson());

      return Vehicle.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível cadastrar o veículo.'),
      );
    }
  }

  Future<Vehicle> update(String id, UpdateVehicleRequest request) async {
    try {
      final response = await _dio.patch(
        '/veiculos/$id',
        data: request.toJson(),
      );

      return Vehicle.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível atualizar o veículo.'),
      );
    }
  }

  Future<String> delete(String id) async {
    try {
      final response = await _dio.delete('/veiculos/$id');

      return response.data['mensagem']?.toString() ??
          'Veículo removido com sucesso.';
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível remover o veículo.'),
      );
    }
  }

  Future<String> setPrincipal(String id) async {
    try {
      final response = await _dio.patch('/veiculos/$id/principal');

      return response.data['mensagem']?.toString() ??
          'Veículo definido como principal.';
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível definir o veículo principal.'),
      );
    }
  }

  Future<String> reactivate(String id) async {
    try {
      final response = await _dio.patch('/veiculos/$id/reativar');

      return response.data['mensagem']?.toString() ??
          'Veículo reativado com sucesso.';
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível reativar o veículo.'),
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
