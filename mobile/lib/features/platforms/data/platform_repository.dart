import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';
import '../../sync/data/sync_local_repository.dart';
import '../../sync/services/sync_manager.dart';
import 'platform.dart';

class PlatformRepository {
  final SyncLocalRepository _localRepository;

  final SyncManager _syncManager;

  PlatformRepository({
    required SyncLocalRepository localRepository,
    required SyncManager syncManager,
  }) : _localRepository = localRepository,
       _syncManager = syncManager;

  Future<List<Platform>> findAll() async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      DatabaseTables.plataformasCache,
      orderBy:
          'padrao DESC, '
          'ativa DESC, '
          'nome ASC',
    );

    return rows.map(_platformFromRow).toList();
  }

  Future<Platform> create(String nome) async {
    final cleanName = nome.trim();

    _validateName(cleanName);

    await _validateLocalDuplicate(cleanName);

    final userId = AppDatabase.instance.activeUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('Nenhum usuário ativo para salvar a plataforma.');
    }

    final now = DateTime.now().toUtc();

    final state = <String, dynamic>{
      'id_plataforma': const Uuid().v4(),
      'id_usuario': userId,
      'nome': cleanName,
      'ativa': true,
      'padrao': false,
      'data_atualizacao': now.toIso8601String(),
    };

    await _saveState(state, now);

    await trySync();

    return Platform.fromJson(state);
  }

  Future<Platform> update(String id, String nome) async {
    final current = await _findOne(id);

    if (current.padrao) {
      throw Exception(
        'Plataformas padrão do sistema '
        'não podem ter o nome alterado.',
      );
    }

    final cleanName = nome.trim();

    _validateName(cleanName);

    await _validateLocalDuplicate(cleanName, ignoreId: id);

    final now = DateTime.now().toUtc();

    final state = _platformState(current, nome: cleanName, atualizadoEm: now);

    await _saveState(state, now);

    await trySync();

    return Platform.fromJson(state);
  }

  Future<Platform> toggleActive(String id) async {
    final current = await _findOne(id);

    final now = DateTime.now().toUtc();

    final state = _platformState(
      current,
      ativa: !current.ativa,
      atualizadoEm: now,
    );

    await _saveState(state, now);

    await trySync();

    return Platform.fromJson(state);
  }

  Future<Set<String>> pendingIds() {
    return _localRepository.pendingRecordIds(entidade: 'plataforma');
  }

  Future<Map<String, String>> attentionReasons() async {
    final items = await _localRepository.findNeedsAttention();

    return {
      for (final item in items)
        if (item.entidade == 'plataforma')
          item.registroId:
              item.motivoErro ?? 'A sincronização precisa de atenção.',
    };
  }

  Future<void> trySync() async {
    try {
      await _syncManager.syncNow();
    } catch (_) {
      // Offline:
      // mantém SQLite + outbox.
    }
  }

  Platform _platformFromRow(Map<String, Object?> row) {
    final rawJson = row['raw_json']?.toString();

    if (rawJson != null && rawJson.isNotEmpty) {
      final decoded = jsonDecode(rawJson);

      if (decoded is Map) {
        final json = Map<String, dynamic>.from(decoded);

        json['id_plataforma'] = row['id_plataforma'].toString();

        json['nome'] = row['nome']?.toString() ?? json['nome'];

        json['ativa'] = (row['ativa'] as num?)?.toInt() == 1;

        json['padrao'] = (row['padrao'] as num?)?.toInt() == 1;

        return Platform.fromJson(json);
      }
    }

    throw Exception('Dados locais da plataforma estão incompletos.');
  }

  Future<Platform> _findOne(String id) async {
    final platforms = await findAll();

    for (final platform in platforms) {
      if (platform.idPlataforma == id) {
        return platform;
      }
    }

    throw Exception('Plataforma não encontrada.');
  }

  Future<void> _saveState(Map<String, dynamic> state, DateTime now) async {
    await _localRepository.upsertPlataforma(state);

    await _localRepository.enqueueUpsert(
      entidade: 'plataforma',
      registroId: state['id_plataforma'].toString(),
      payload: {
        'id_plataforma': state['id_plataforma'],
        'nome': state['nome'],
        'ativa': state['ativa'],

        // NÃO enviar "padrao".
        'atualizado_em': now.toUtc().toIso8601String(),
      },
      atualizadoEm: now,
    );
  }

  Map<String, dynamic> _platformState(
    Platform current, {
    String? nome,
    bool? ativa,
    required DateTime atualizadoEm,
  }) {
    return {
      'id_plataforma': current.idPlataforma,
      'id_usuario': current.idUsuario,
      'nome': nome ?? current.nome,
      'ativa': ativa ?? current.ativa,
      'padrao': current.padrao,
      'data_atualizacao': atualizadoEm.toUtc().toIso8601String(),
    };
  }

  Future<void> _validateLocalDuplicate(String name, {String? ignoreId}) async {
    final normalized = name.toLowerCase();

    final platforms = await findAll();

    for (final platform in platforms) {
      if (platform.idPlataforma == ignoreId) {
        continue;
      }

      if (platform.nome.trim().toLowerCase() == normalized) {
        throw Exception('Já existe uma plataforma com esse nome.');
      }
    }
  }

  void _validateName(String name) {
    if (name.isEmpty) {
      throw Exception('O nome da plataforma é obrigatório.');
    }

    if (name.length > 60) {
      throw Exception('O nome da plataforma deve ter no máximo 60 caracteres.');
    }
  }
}
