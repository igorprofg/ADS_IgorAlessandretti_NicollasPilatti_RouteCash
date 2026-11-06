import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_tables.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const int _databaseVersion = 1;

  Database? _database;
  String? _activeUserId;

  String? get activeUserId => _activeUserId;

  /// Define qual usuário está utilizando
  /// o banco local neste momento.
  Future<void> useUser(String userId) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw ArgumentError('O id do usuário não pode ser vazio.');
    }

    // Já estamos utilizando o banco correto.
    if (_activeUserId == normalizedUserId &&
        _database != null &&
        _database!.isOpen) {
      return;
    }

    // Fecha o banco do usuário anterior.
    await _closeDatabase();

    _activeUserId = normalizedUserId;

    // Abre/cria o banco do usuário atual.
    _database = await _openDatabase(normalizedUserId);
  }

  Future<Database> get database async {
    final userId = _activeUserId;

    if (userId == null || userId.isEmpty) {
      throw StateError('Nenhum usuário ativo foi definido para o banco local.');
    }

    final current = _database;

    if (current != null && current.isOpen) {
      return current;
    }

    _database = await _openDatabase(userId);

    return _database!;
  }

  Future<Database> _openDatabase(String userId) async {
    final basePath = await getDatabasesPath();

    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    final databaseName = 'route_cash_$safeUserId.db';

    final databasePath = p.join(basePath, databaseName);

    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        final batch = db.batch();

        for (final statement in DatabaseTables.createStatements) {
          batch.execute(statement);
        }

        await batch.commit(noResult: true);
      },
    );
  }

  Future<void> clearAllLocalData() async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(DatabaseTables.syncOutbox);

      await txn.delete(DatabaseTables.ganhosLocal);

      await txn.delete(DatabaseTables.despesasLocal);

      await txn.delete(DatabaseTables.jornadasLocal);

      await txn.delete(DatabaseTables.veiculosCache);

      await txn.delete(DatabaseTables.plataformasCache);

      await txn.delete(DatabaseTables.categoriasCache);
    });
  }

  /// Fecha o banco atual,
  /// mas mantém o usuário selecionado.
  Future<void> close() async {
    await _closeDatabase();
  }

  Future<void> _closeDatabase() async {
    final current = _database;

    if (current != null && current.isOpen) {
      await current.close();
    }

    _database = null;
  }

  /// Usado no logout.
  ///
  /// Fecha o banco atual e remove
  /// a referência ao usuário ativo.
  ///
  /// NÃO apaga os dados locais.
  Future<void> releaseUser() async {
    await _closeDatabase();

    _activeUserId = null;
  }

  /// Exclui somente o banco do
  /// usuário atualmente ativo.
  Future<void> deleteDatabaseFile() async {
    final userId = _activeUserId;

    if (userId == null || userId.isEmpty) {
      return;
    }

    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    final basePath = await getDatabasesPath();

    final databasePath = p.join(basePath, 'route_cash_$safeUserId.db');

    await _closeDatabase();

    await deleteDatabase(databasePath);
  }
}
