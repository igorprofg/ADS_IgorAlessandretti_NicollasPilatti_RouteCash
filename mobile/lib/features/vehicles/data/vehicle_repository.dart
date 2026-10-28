import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'create_vehicle_request.dart';
import 'update_vehicle_request.dart';
import 'vehicle.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';
import 'dart:convert';

class InactiveVehicleConflict implements Exception {
  final String message;
  final String vehicleId;

  const InactiveVehicleConflict({
    required this.message,
    required this.vehicleId,
  });

  @override
  String toString() => message;
}

class VehicleRepository {
  final Dio _dio;

  VehicleRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<List<Vehicle>> findAll() async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      DatabaseTables.veiculosCache,
      orderBy: 'principal DESC, ativo DESC, marca ASC, modelo ASC',
    );

    return rows.map((row) {
      final rawJson = row['raw_json']?.toString();

      if (rawJson != null && rawJson.isNotEmpty) {
        final json = jsonDecode(rawJson) as Map<String, dynamic>;

        return Vehicle.fromJson(json);
      }

      return Vehicle.fromJson({
        'id_veiculo': row['id_veiculo'].toString(),
        'marca': row['marca']?.toString() ?? '',
        'modelo': row['modelo']?.toString() ?? '',
        'placa': row['placa']?.toString(),
        'ativo': (row['ativo'] as num?)?.toInt() == 1,
        'principal': (row['principal'] as num?)?.toInt() == 1,
      });
    }).toList();
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
      final conflito = _getInactiveVehicleConflict(e);

      if (conflito != null) {
        throw conflito;
      }

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
      final conflito = _getInactiveVehicleConflict(e);

      if (conflito != null) {
        throw conflito;
      }

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

  Future<Vehicle> reactivate(String id) async {
    try {
      final response = await _dio.patch('/veiculos/$id/reativar');

      return Vehicle.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, 'Não foi possível reativar o veículo.'),
      );
    }
  }

  InactiveVehicleConflict? _getInactiveVehicleConflict(DioException e) {
    if (e.response?.statusCode != 409) {
      return null;
    }

    final data = e.response?.data;

    if (data is! Map) {
      return null;
    }

    final id = data['id_veiculo_inativo']?.toString();

    if (id == null || id.isEmpty) {
      return null;
    }

    final message =
        data['message']?.toString() ??
        'Este veículo já está cadastrado e está inativo.';

    return InactiveVehicleConflict(message: message, vehicleId: id);
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
