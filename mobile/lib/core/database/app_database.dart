import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_tables.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _databaseName = 'route_cash.db';
  static const int _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    final current = _database;

    if (current != null && current.isOpen) {
      return current;
    }

    _database = await _openDatabase();

    return _database!;
  }

  Future<Database> _openDatabase() async {
    final basePath = await getDatabasesPath();
    final databasePath = p.join(
      basePath,
      _databaseName,
    );

    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute(
          'PRAGMA foreign_keys = ON',
        );
      },
      onCreate: (db, version) async {
        final batch = db.batch();

        for (final statement
            in DatabaseTables.createStatements) {
          batch.execute(statement);
        }

        await batch.commit(
          noResult: true,
        );
      },
    );
  }

  Future<void> clearAllLocalData() async {
    final db = await database;

    await db.transaction(
      (txn) async {
        await txn.delete(
          DatabaseTables.syncOutbox,
        );

        await txn.delete(
          DatabaseTables.ganhosLocal,
        );

        await txn.delete(
          DatabaseTables.despesasLocal,
        );

        await txn.delete(
          DatabaseTables.jornadasLocal,
        );

        await txn.delete(
          DatabaseTables.veiculosCache,
        );

        await txn.delete(
          DatabaseTables.plataformasCache,
        );

        await txn.delete(
          DatabaseTables.categoriasCache,
        );
      },
    );
  }

  Future<void> close() async {
    final current = _database;

    if (current != null &&
        current.isOpen) {
      await current.close();
    }

    _database = null;
  }

  Future<void> deleteDatabaseFile() async {
    await close();

    final basePath = await getDatabasesPath();
    final databasePath = p.join(
      basePath,
      _databaseName,
    );

    await deleteDatabase(
      databasePath,
    );
  }
}
