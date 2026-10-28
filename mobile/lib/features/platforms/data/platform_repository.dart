import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'platform.dart';
import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';

class PlatformRepository {
  final Dio _dio;

  PlatformRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<List<Platform>> findAll() async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      DatabaseTables.plataformasCache,
      orderBy: 'padrao DESC, ativa DESC, nome ASC',
    );

    return rows.map((row) {
      final rawJson = row['raw_json']?.toString();

      if (rawJson != null && rawJson.isNotEmpty) {
        final json = jsonDecode(rawJson) as Map<String, dynamic>;

        return Platform.fromJson(json);
      }

      return Platform.fromJson({
        'id_plataforma': row['id_plataforma'].toString(),
        'nome': row['nome']?.toString() ?? '',
        'ativa': (row['ativa'] as num?)?.toInt() == 1,
        'padrao': (row['padrao'] as num?)?.toInt() == 1,
      });
    }).toList();
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
