import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';
import '../../sync/data/sync_local_repository.dart';
import '../../sync/services/sync_manager.dart';
import 'expense.dart';

class ExpenseVehicleOption {
  final String idVeiculo;
  final String marca;
  final String modelo;
  final bool principal;

  const ExpenseVehicleOption({
    required this.idVeiculo,
    required this.marca,
    required this.modelo,
    required this.principal,
  });

  String get nome => '$marca $modelo'.trim();
}

class ExpenseCategoryOption {
  final String idCategoria;
  final String nome;

  const ExpenseCategoryOption({required this.idCategoria, required this.nome});
}

class ExpenseReferenceData {
  final List<ExpenseVehicleOption> vehicles;
  final List<ExpenseCategoryOption> categories;

  const ExpenseReferenceData({
    required this.vehicles,
    required this.categories,
  });
}

class ExpenseRepository {
  final SyncLocalRepository _localRepository;
  final SyncManager _syncManager;

  ExpenseRepository({
    required SyncLocalRepository localRepository,
    required SyncManager syncManager,
  }) : _localRepository = localRepository,
       _syncManager = syncManager;

  Future<List<Expense>> findAll() async {
    final db = await AppDatabase.instance.database;

    final rows = await db.rawQuery('''
      SELECT
        d.id_despesa,
        d.id_veiculo,
        d.id_categoria,
        d.valor,
        d.data,
        d.observacao,
        d.atualizado_em,
        v.marca AS veiculo_marca,
        v.modelo AS veiculo_modelo,
        c.nome AS categoria_nome
      FROM ${DatabaseTables.despesasLocal} d
      LEFT JOIN ${DatabaseTables.veiculosCache} v
        ON v.id_veiculo = d.id_veiculo
      LEFT JOIN ${DatabaseTables.categoriasCache} c
        ON c.id_categoria = d.id_categoria
      ORDER BY d.data DESC, d.atualizado_em DESC
      ''');

    return rows.map((row) {
      return Expense.fromJson({
        'id_despesa': row['id_despesa'].toString(),
        'id_veiculo': row['id_veiculo'].toString(),
        'id_categoria': row['id_categoria'].toString(),
        'valor': (row['valor'] as num).toDouble(),
        'data': row['data'].toString(),
        'observacao': row['observacao']?.toString(),
        'veiculo': {
          'marca': row['veiculo_marca']?.toString(),
          'modelo': row['veiculo_modelo']?.toString(),
        },
        'categoria': {'nome': row['categoria_nome']?.toString()},
      });
    }).toList();
  }

  Future<ExpenseReferenceData> loadReferenceData() async {
    await trySync();

    final db = await AppDatabase.instance.database;

    final vehicleRows = await db.query(
      DatabaseTables.veiculosCache,
      columns: ['id_veiculo', 'marca', 'modelo', 'principal'],
      where: 'ativo = ?',
      whereArgs: [1],
      orderBy: 'principal DESC, marca ASC, modelo ASC',
    );

    final categoryRows = await db.query(
      DatabaseTables.categoriasCache,
      columns: ['id_categoria', 'nome'],
      orderBy: 'nome ASC',
    );

    final vehicles = vehicleRows
        .map(
          (row) => ExpenseVehicleOption(
            idVeiculo: row['id_veiculo'].toString(),
            marca: row['marca']?.toString() ?? '',
            modelo: row['modelo']?.toString() ?? '',
            principal: (row['principal'] as num?)?.toInt() == 1,
          ),
        )
        .toList();

    final categories = categoryRows
        .map(
          (row) => ExpenseCategoryOption(
            idCategoria: row['id_categoria'].toString(),
            nome: row['nome']?.toString() ?? '',
          ),
        )
        .toList();

    return ExpenseReferenceData(vehicles: vehicles, categories: categories);
  }

  Future<bool> save({
    required String idDespesa,
    required String idVeiculo,
    required String idCategoria,
    required double valor,
    required DateTime data,
    required String? observacao,
  }) async {
    final now = DateTime.now().toUtc();

    final payload = <String, dynamic>{
      'id_despesa': idDespesa,
      'id_veiculo': idVeiculo,
      'id_categoria': idCategoria,
      'valor': valor,
      'data': _formatDate(data),
      'observacao': _cleanObservation(observacao),
      'atualizado_em': now.toIso8601String(),
    };

    // 1. Salva no celular.
    await _localRepository.upsertDespesa(payload);

    // 2. Coloca na fila.
    await _localRepository.enqueueUpsert(
      entidade: 'despesa',
      registroId: idDespesa,
      payload: payload,
      atualizadoEm: now,
    );

    // 3. Tenta enviar, mas falha de rede não impede o salvamento.
    await trySync();

    // 4. Se ainda existir na fila, está pendente.
    return _localRepository.hasPending(
      entidade: 'despesa',
      registroId: idDespesa,
    );
  }

  Future<bool> delete(String idDespesa) async {
    await _localRepository.deleteDespesa(idDespesa);

    await _localRepository.enqueueDelete(
      entidade: 'despesa',
      registroId: idDespesa,
    );

    await trySync();

    return _localRepository.hasPending(
      entidade: 'despesa',
      registroId: idDespesa,
    );
  }

  Future<Set<String>> pendingIds() {
    return _localRepository.pendingRecordIds(entidade: 'despesa');
  }

  Future<void> trySync() async {
    try {
      await _syncManager.syncNow();
    } catch (_) {
      // Sem conexão ou backend indisponível.
      // A despesa continua salva no SQLite e na outbox.
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String? _cleanObservation(String? value) {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) {
      return null;
    }

    return clean;
  }
}
