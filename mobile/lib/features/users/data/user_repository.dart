import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';
import '../../../core/network/dio_client.dart';

import 'create_user_request.dart';

class UserRepository {
  final Dio _dio;

  UserRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _dio.get('/usuarios/me');

      final usuario = _extractProfile(response.data);

      await _saveProfileCache(usuario);

      return usuario;
    } on DioException catch (e) {
      if (_canUseCache(e)) {
        final cached = await getCachedProfile();

        if (cached != null) {
          return cached;
        }
      }

      final message = _extractErrorMessage(e);

      if (message != null) {
        throw Exception(message);
      }

      throw Exception('Não foi possível carregar o perfil.');
    }
  }

  Future<Map<String, dynamic>?> getCachedProfile() async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(DatabaseTables.usuarioCache, limit: 1);

    if (rows.isEmpty) {
      return null;
    }

    final raw = rows.first['raw_json']?.toString();

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);

        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Se o JSON estiver inválido,
        // utiliza as colunas básicas.
      }
    }

    final row = rows.first;

    return {
      'id_usuario': row['id_usuario']?.toString(),
      'nome': row['nome']?.toString() ?? '',
      'email': row['email']?.toString() ?? '',
      'tipo_usuario': row['tipo_usuario']?.toString() ?? '',
      'status_conta': row['status_conta']?.toString(),
    };
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

  Future<Map<String, dynamic>> updateMyProfile({required String nome}) async {
    try {
      final response = await _dio.patch('/usuarios/me', data: {'nome': nome});

      final remoteProfile = _extractProfile(response.data);

      final cached = await getCachedProfile();

      final usuario = <String, dynamic>{
        if (cached != null) ...cached,
        ...remoteProfile,

        // Garante o nome novo mesmo
        // caso o PATCH devolva apenas
        // parte do usuário.
        'nome': remoteProfile['nome']?.toString() ?? nome,
      };

      await _saveProfileCache(usuario);

      return usuario;
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);

      if (message != null) {
        throw Exception(message);
      }

      if (_canUseCache(e)) {
        throw Exception('É necessário estar online para atualizar o perfil.');
      }

      throw Exception('Não foi possível atualizar o perfil.');
    }
  }

  Future<String> deleteMyAccount() async {
    try {
      final response = await _dio.delete('/usuarios/me');

      final data = Map<String, dynamic>.from(response.data as Map);

      return data['mensagem']?.toString() ?? 'Conta encerrada com sucesso.';
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);

      if (message != null) {
        throw Exception(message);
      }

      if (_canUseCache(e)) {
        throw Exception('É necessário estar online para encerrar a conta.');
      }

      throw Exception('Não foi possível encerrar a conta.');
    }
  }

  Future<void> _saveProfileCache(Map<String, dynamic> usuario) async {
    final activeUserId = AppDatabase.instance.activeUserId;

    final userId = usuario['id_usuario']?.toString() ?? activeUserId;

    if (userId == null || userId.trim().isEmpty) {
      return;
    }

    final nome = usuario['nome']?.toString().trim() ?? '';

    final email = usuario['email']?.toString().trim() ?? '';

    final tipoUsuario = usuario['tipo_usuario']?.toString() ?? '';

    final statusConta = usuario['status_conta']?.toString();

    final agora = DateTime.now().toUtc().toIso8601String();

    final completo = <String, dynamic>{
      ...usuario,
      'id_usuario': userId,
      'nome': nome,
      'email': email,
      'tipo_usuario': tipoUsuario,
      if (statusConta != null) 'status_conta': statusConta,
    };

    final db = await AppDatabase.instance.database;

    await db.insert(DatabaseTables.usuarioCache, {
      'id_usuario': userId,
      'nome': nome,
      'email': email,
      'tipo_usuario': tipoUsuario,
      'status_conta': statusConta,
      'atualizado_em': agora,
      'raw_json': jsonEncode(completo),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, dynamic> _extractProfile(dynamic data) {
    if (data is! Map) {
      throw Exception('Resposta inválida ao carregar o perfil.');
    }

    final map = Map<String, dynamic>.from(data);

    final usuario = map['usuario'];

    if (usuario is Map) {
      return Map<String, dynamic>.from(usuario);
    }

    return map;
  }

  bool _canUseCache(DioException e) {
    if (e.response == null) {
      return true;
    }

    final status = e.response?.statusCode;

    // Servidor temporariamente
    // indisponível também pode usar
    // o último perfil conhecido.
    if (status != null && status >= 500) {
      return true;
    }

    // 401 / 403 não utilizam cache,
    // pois a sessão pode estar
    // inválida ou bloqueada.
    return false;
  }

  String? _extractErrorMessage(DioException e) {
    final data = e.response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message'];

      if (message is String && message.isNotEmpty) {
        return message;
      }

      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
    }

    return null;
  }
}
