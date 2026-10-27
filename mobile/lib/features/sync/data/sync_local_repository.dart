import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';
import 'sync_outbox_item.dart';
import 'sync_snapshot.dart';

class SyncLocalRepository {
  final AppDatabase _appDatabase;

  SyncLocalRepository({AppDatabase? appDatabase})
    : _appDatabase = appDatabase ?? AppDatabase.instance;

  Future<Database> get _db => _appDatabase.database;

  // ------------------------------------------------------------
  // OUTBOX
  // ------------------------------------------------------------

  Future<void> enqueueUpsert({
    required String entidade,
    required String registroId,
    required Map<String, dynamic> payload,
    DateTime? atualizadoEm,
  }) async {
    await _upsertOutbox(
      entidade: entidade,
      registroId: registroId,
      operacao: 'upsert',
      payloadJson: jsonEncode(payload),
      atualizadoEm: atualizadoEm ?? DateTime.now(),
    );
  }

  Future<void> enqueueDelete({
    required String entidade,
    required String registroId,
    DateTime? atualizadoEm,
  }) async {
    await _upsertOutbox(
      entidade: entidade,
      registroId: registroId,
      operacao: 'delete',
      payloadJson: null,
      atualizadoEm: atualizadoEm ?? DateTime.now(),
    );
  }

  Future<void> _upsertOutbox({
    required String entidade,
    required String registroId,
    required String operacao,
    required String? payloadJson,
    required DateTime atualizadoEm,
  }) async {
    final db = await _db;

    await db.transaction((txn) async {
      final existing = await txn.query(
        DatabaseTables.syncOutbox,
        columns: ['id'],
        where: 'entidade = ? AND registro_id = ?',
        whereArgs: [entidade, registroId],
        limit: 1,
      );

      final values = <String, Object?>{
        'entidade': entidade,
        'registro_id': registroId,
        'operacao': operacao,
        'payload_json': payloadJson,
        'estado': 'pendente',
        'codigo_erro': null,
        'motivo_erro': null,
        'tentativas': 0,
        'atualizado_em': atualizadoEm.toUtc().toIso8601String(),
      };

      if (existing.isEmpty) {
        await txn.insert(DatabaseTables.syncOutbox, values);
      } else {
        await txn.update(
          DatabaseTables.syncOutbox,
          values,
          where: 'entidade = ? AND registro_id = ?',
          whereArgs: [entidade, registroId],
        );
      }
    });
  }

  Future<List<SyncOutboxItem>> findPending({int limit = 200}) async {
    final db = await _db;

    final rows = await db.query(
      DatabaseTables.syncOutbox,
      where: 'estado = ?',
      whereArgs: ['pendente'],
      orderBy: 'atualizado_em ASC',
      limit: limit,
    );

    return rows.map(SyncOutboxItem.fromMap).toList();
  }

  Future<List<SyncOutboxItem>> findNeedsAttention() async {
    final db = await _db;

    final rows = await db.query(
      DatabaseTables.syncOutbox,
      where: 'estado = ?',
      whereArgs: ['atencao'],
      orderBy: 'atualizado_em DESC',
    );

    return rows.map(SyncOutboxItem.fromMap).toList();
  }

  Future<bool> hasPending({
    required String entidade,
    required String registroId,
  }) async {
    final db = await _db;

    final result = await db.query(
      DatabaseTables.syncOutbox,
      columns: ['id'],
      where: 'entidade = ? AND registro_id = ?',
      whereArgs: [entidade, registroId],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<Set<String>> pendingRecordIds({String? entidade}) async {
    final db = await _db;

    final rows = await db.query(
      DatabaseTables.syncOutbox,
      columns: ['registro_id'],
      where: entidade == null ? null : 'entidade = ?',
      whereArgs: entidade == null ? null : [entidade],
    );

    return rows.map((row) => row['registro_id'].toString()).toSet();
  }

  Future<void> removeOutbox({
    required String entidade,
    required String registroId,
  }) async {
    final db = await _db;

    await db.delete(
      DatabaseTables.syncOutbox,
      where: 'entidade = ? AND registro_id = ?',
      whereArgs: [entidade, registroId],
    );
  }

  Future<void> markNeedsAttention({
    required String entidade,
    required String registroId,
    required String codigo,
    required String motivo,
  }) async {
    final db = await _db;

    await db.update(
      DatabaseTables.syncOutbox,
      {'estado': 'atencao', 'codigo_erro': codigo, 'motivo_erro': motivo},
      where: 'entidade = ? AND registro_id = ?',
      whereArgs: [entidade, registroId],
    );
  }

  Future<void> markPendingAgain({
    required String entidade,
    required String registroId,
  }) async {
    final db = await _db;

    await db.update(
      DatabaseTables.syncOutbox,
      {
        'estado': 'pendente',
        'codigo_erro': null,
        'motivo_erro': null,
        'tentativas': 0,
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'entidade = ? AND registro_id = ?',
      whereArgs: [entidade, registroId],
    );
  }

  Future<void> incrementAttempts({
    required String entidade,
    required String registroId,
    String? motivoErro,
  }) async {
    final db = await _db;

    await db.rawUpdate(
      '''
      UPDATE ${DatabaseTables.syncOutbox}
      SET tentativas = tentativas + 1,
          codigo_erro = ?,
          motivo_erro = ?
      WHERE entidade = ?
        AND registro_id = ?
      ''',
      ['ERRO_INTERNO', motivoErro, entidade, registroId],
    );
  }

  Future<int> countOutbox() async {
    final db = await _db;

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM ${DatabaseTables.syncOutbox}
      ''');

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ------------------------------------------------------------
  // LOCAL BUSINESS DATA
  // ------------------------------------------------------------

  Future<void> upsertGanho(Map<String, dynamic> payload) async {
    final db = await _db;

    await _upsertGanhoTxn(db, payload);
  }

  Future<void> deleteGanho(String idGanho) async {
    final db = await _db;

    await db.delete(
      DatabaseTables.ganhosLocal,
      where: 'id_ganho = ?',
      whereArgs: [idGanho],
    );
  }

  Future<void> upsertDespesa(Map<String, dynamic> payload) async {
    final db = await _db;

    await _upsertDespesaTxn(db, payload);
  }

  Future<void> deleteDespesa(String idDespesa) async {
    final db = await _db;

    await db.delete(
      DatabaseTables.despesasLocal,
      where: 'id_despesa = ?',
      whereArgs: [idDespesa],
    );
  }

  Future<void> upsertJornada(Map<String, dynamic> payload) async {
    final db = await _db;

    await _upsertJornadaTxn(db, payload);
  }

  Future<void> deleteJornada(String idJornada) async {
    final db = await _db;

    await db.delete(
      DatabaseTables.jornadasLocal,
      where: 'id_jornada = ?',
      whereArgs: [idJornada],
    );
  }

  // ------------------------------------------------------------
  // SNAPSHOT / RECONCILIATION
  // ------------------------------------------------------------

  Future<void> reconcileSnapshot(SyncSnapshot snapshot) async {
    final pendingGains = await pendingRecordIds(entidade: 'ganho');

    final pendingExpenses = await pendingRecordIds(entidade: 'despesa');

    final pendingJourneys = await pendingRecordIds(entidade: 'jornada');

    final db = await _db;

    await db.transaction((txn) async {
      await _replaceCaches(txn, snapshot);

      await _reconcileGains(
        txn,
        snapshot.ganhos,
        pendingGains,
        snapshot.sincronizadoEm,
      );

      await _reconcileExpenses(
        txn,
        snapshot.despesas,
        pendingExpenses,
        snapshot.sincronizadoEm,
      );

      await _reconcileJourneys(
        txn,
        snapshot.jornadas,
        pendingJourneys,
        snapshot.sincronizadoEm,
      );
    });
  }

  Future<void> _replaceCaches(
    DatabaseExecutor txn,
    SyncSnapshot snapshot,
  ) async {
    await txn.delete(DatabaseTables.veiculosCache);

    await txn.delete(DatabaseTables.plataformasCache);

    await txn.delete(DatabaseTables.categoriasCache);

    for (final item in snapshot.veiculos) {
      await txn.insert(DatabaseTables.veiculosCache, {
        'id_veiculo': item['id_veiculo'].toString(),
        'marca': item['marca']?.toString() ?? '',
        'modelo': item['modelo']?.toString() ?? '',
        'placa': item['placa']?.toString(),
        'ativo': _boolToInt(item['ativo']),
        'principal': _boolToInt(item['principal']),
        'raw_json': jsonEncode(item),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final item in snapshot.plataformas) {
      await txn.insert(
        DatabaseTables.plataformasCache,
        {
          'id_plataforma': item['id_plataforma'].toString(),
          'nome': item['nome']?.toString() ?? '',
          'ativa': _boolToInt(item['ativa']),
          'padrao': _boolToInt(item['padrao']),
          'raw_json': jsonEncode(item),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final item in snapshot.categoriasDespesa) {
      await txn.insert(
        DatabaseTables.categoriasCache,
        {
          'id_categoria': item['id_categoria'].toString(),
          'nome': item['nome']?.toString() ?? '',
          'raw_json': jsonEncode(item),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _reconcileGains(
    DatabaseExecutor txn,
    List<Map<String, dynamic>> serverItems,
    Set<String> protectedIds,
    DateTime fallbackUpdatedAt,
  ) async {
    final serverIds = <String>{};

    for (final item in serverItems) {
      final id = item['id_ganho'].toString();

      serverIds.add(id);

      if (protectedIds.contains(id)) {
        continue;
      }

      await _upsertGanhoTxn(txn, {
        ...item,
        'atualizado_em': _serverUpdatedAt(item, fallbackUpdatedAt),
      });
    }

    final localRows = await txn.query(
      DatabaseTables.ganhosLocal,
      columns: ['id_ganho'],
    );

    for (final row in localRows) {
      final id = row['id_ganho'].toString();

      if (!serverIds.contains(id) && !protectedIds.contains(id)) {
        await txn.delete(
          DatabaseTables.ganhosLocal,
          where: 'id_ganho = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<void> _reconcileExpenses(
    DatabaseExecutor txn,
    List<Map<String, dynamic>> serverItems,
    Set<String> protectedIds,
    DateTime fallbackUpdatedAt,
  ) async {
    final serverIds = <String>{};

    for (final item in serverItems) {
      final id = item['id_despesa'].toString();

      serverIds.add(id);

      if (protectedIds.contains(id)) {
        continue;
      }

      await _upsertDespesaTxn(txn, {
        ...item,
        'atualizado_em': _serverUpdatedAt(item, fallbackUpdatedAt),
      });
    }

    final localRows = await txn.query(
      DatabaseTables.despesasLocal,
      columns: ['id_despesa'],
    );

    for (final row in localRows) {
      final id = row['id_despesa'].toString();

      if (!serverIds.contains(id) && !protectedIds.contains(id)) {
        await txn.delete(
          DatabaseTables.despesasLocal,
          where: 'id_despesa = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<void> _reconcileJourneys(
    DatabaseExecutor txn,
    List<Map<String, dynamic>> serverItems,
    Set<String> protectedIds,
    DateTime fallbackUpdatedAt,
  ) async {
    final serverIds = <String>{};

    for (final item in serverItems) {
      final id = item['id_jornada'].toString();

      serverIds.add(id);

      if (protectedIds.contains(id)) {
        continue;
      }

      await _upsertJornadaTxn(txn, {
        ...item,
        'atualizado_em': _serverUpdatedAt(item, fallbackUpdatedAt),
      });
    }

    final localRows = await txn.query(
      DatabaseTables.jornadasLocal,
      columns: ['id_jornada'],
    );

    for (final row in localRows) {
      final id = row['id_jornada'].toString();

      if (!serverIds.contains(id) && !protectedIds.contains(id)) {
        await txn.delete(
          DatabaseTables.jornadasLocal,
          where: 'id_jornada = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<void> _upsertGanhoTxn(
    DatabaseExecutor db,
    Map<String, dynamic> payload,
  ) async {
    await db.insert(DatabaseTables.ganhosLocal, {
      'id_ganho': payload['id_ganho'].toString(),
      'id_veiculo': payload['id_veiculo'].toString(),
      'id_plataforma': payload['id_plataforma'].toString(),
      'valor': (payload['valor'] as num).toDouble(),
      'data': payload['data'].toString(),
      'observacao': payload['observacao']?.toString(),
      'atualizado_em': payload['atualizado_em'].toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _upsertDespesaTxn(
    DatabaseExecutor db,
    Map<String, dynamic> payload,
  ) async {
    await db.insert(DatabaseTables.despesasLocal, {
      'id_despesa': payload['id_despesa'].toString(),
      'id_veiculo': payload['id_veiculo'].toString(),
      'id_categoria': payload['id_categoria'].toString(),
      'valor': (payload['valor'] as num).toDouble(),
      'data': payload['data'].toString(),
      'observacao': payload['observacao']?.toString(),
      'atualizado_em': payload['atualizado_em'].toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _upsertJornadaTxn(
    DatabaseExecutor db,
    Map<String, dynamic> payload,
  ) async {
    await db.insert(DatabaseTables.jornadasLocal, {
      'id_jornada': payload['id_jornada'].toString(),
      'id_veiculo': payload['id_veiculo'].toString(),
      'inicio': payload['inicio'].toString(),
      'fim': payload['fim']?.toString(),
      'km_rodados': (payload['km_rodados'] as num?)?.toDouble(),
      'atualizado_em': payload['atualizado_em'].toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _serverUpdatedAt(Map<String, dynamic> item, DateTime fallback) {
    final value = item['data_atualizacao'] ?? item['atualizado_em'];

    if (value != null) {
      return value.toString();
    }

    return fallback.toUtc().toIso8601String();
  }

  int _boolToInt(dynamic value) {
    if (value == true || value == 1 || value == 'true' || value == '1') {
      return 1;
    }

    return 0;
  }

  Future<Map<String, int>> localCounts() async {
    final db = await _db;

    Future<int> count(String table) async {
      final result = await db.rawQuery('SELECT COUNT(*) FROM $table');

      return Sqflite.firstIntValue(result) ?? 0;
    }

    return {
      'ganhos': await count(DatabaseTables.ganhosLocal),
      'despesas': await count(DatabaseTables.despesasLocal),
      'jornadas': await count(DatabaseTables.jornadasLocal),
      'veiculos': await count(DatabaseTables.veiculosCache),
      'plataformas': await count(DatabaseTables.plataformasCache),
      'categorias': await count(DatabaseTables.categoriasCache),
      'outbox': await count(DatabaseTables.syncOutbox),
    };
  }

  Future<void> clearAll() {
    return _appDatabase.clearAllLocalData();
  }
}
