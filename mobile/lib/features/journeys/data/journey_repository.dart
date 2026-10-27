import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';
import '../../sync/data/sync_local_repository.dart';
import '../../sync/services/sync_manager.dart';
import 'journey.dart';

class JourneyVehicleOption {
  final String idVeiculo;
  final String marca;
  final String modelo;
  final bool principal;

  const JourneyVehicleOption({
    required this.idVeiculo,
    required this.marca,
    required this.modelo,
    required this.principal,
  });

  String get nome {
    return '$marca $modelo'.trim();
  }
}

class JourneySaveResult {
  final Journey journey;
  final bool pending;

  const JourneySaveResult({required this.journey, required this.pending});
}

class JourneyRepository {
  final SyncLocalRepository _localRepository;
  final SyncManager _syncManager;

  JourneyRepository({
    required SyncLocalRepository localRepository,
    required SyncManager syncManager,
  }) : _localRepository = localRepository,
       _syncManager = syncManager;

  Future<List<Journey>> findAll() async {
    final db = await AppDatabase.instance.database;

    final rows = await db.rawQuery('''
      SELECT
        j.id_jornada,
        j.id_veiculo,
        j.inicio,
        j.fim,
        j.km_rodados,
        j.atualizado_em,
        v.marca AS veiculo_marca,
        v.modelo AS veiculo_modelo,
        v.placa AS veiculo_placa
      FROM ${DatabaseTables.jornadasLocal} j
      LEFT JOIN ${DatabaseTables.veiculosCache} v
        ON v.id_veiculo = j.id_veiculo
      ORDER BY j.inicio DESC
      ''');

    return rows.map(_journeyFromRow).toList();
  }

  Future<Journey?> findInProgress() async {
    final db = await AppDatabase.instance.database;

    final rows = await db.rawQuery('''
      SELECT
        j.id_jornada,
        j.id_veiculo,
        j.inicio,
        j.fim,
        j.km_rodados,
        j.atualizado_em,
        v.marca AS veiculo_marca,
        v.modelo AS veiculo_modelo,
        v.placa AS veiculo_placa
      FROM ${DatabaseTables.jornadasLocal} j
      LEFT JOIN ${DatabaseTables.veiculosCache} v
        ON v.id_veiculo = j.id_veiculo
      WHERE j.fim IS NULL
      ORDER BY j.inicio DESC
      LIMIT 1
      ''');

    if (rows.isEmpty) {
      return null;
    }

    return _journeyFromRow(rows.first);
  }

  Future<Journey?> findOne(String idJornada) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        j.id_jornada,
        j.id_veiculo,
        j.inicio,
        j.fim,
        j.km_rodados,
        j.atualizado_em,
        v.marca AS veiculo_marca,
        v.modelo AS veiculo_modelo,
        v.placa AS veiculo_placa
      FROM ${DatabaseTables.jornadasLocal} j
      LEFT JOIN ${DatabaseTables.veiculosCache} v
        ON v.id_veiculo = j.id_veiculo
      WHERE j.id_jornada = ?
      LIMIT 1
      ''',
      [idJornada],
    );

    if (rows.isEmpty) {
      return null;
    }

    return _journeyFromRow(rows.first);
  }

  Future<List<JourneyVehicleOption>> loadVehicles() async {
    await trySync();

    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      DatabaseTables.veiculosCache,
      columns: ['id_veiculo', 'marca', 'modelo', 'principal'],
      where: 'ativo = ?',
      whereArgs: [1],
      orderBy: 'principal DESC, marca ASC, modelo ASC',
    );

    return rows
        .map(
          (row) => JourneyVehicleOption(
            idVeiculo: row['id_veiculo'].toString(),
            marca: row['marca']?.toString() ?? '',
            modelo: row['modelo']?.toString() ?? '',
            principal: (row['principal'] as num?)?.toInt() == 1,
          ),
        )
        .toList();
  }

  Future<JourneySaveResult> start({required String idVeiculo}) async {
    final current = await findInProgress();

    if (current != null) {
      throw Exception('Já existe uma jornada em andamento.');
    }

    final idJornada = const Uuid().v4();

    final inicio = DateTime.now();

    return _save(
      idJornada: idJornada,
      idVeiculo: idVeiculo,
      inicio: inicio,
      fim: null,
      kmRodados: null,
      validateOverlap: true,
    );
  }

  Future<JourneySaveResult> finish({
    required Journey journey,
    DateTime? fim,
    double? kmRodados,
  }) async {
    final fimEfetivo = fim ?? DateTime.now();

    if (!fimEfetivo.isAfter(journey.inicio)) {
      throw Exception('O horário final deve ser posterior ao início.');
    }

    return _save(
      idJornada: journey.idJornada,
      idVeiculo: journey.idVeiculo,
      inicio: journey.inicio,
      fim: fimEfetivo,
      kmRodados: kmRodados ?? journey.kmRodados,
      validateOverlap: true,
    );
  }

  Future<JourneySaveResult> saveManual({
    required String idVeiculo,
    required DateTime inicio,
    required DateTime fim,
    double? kmRodados,
  }) async {
    if (!fim.isAfter(inicio)) {
      throw Exception('O horário final deve ser posterior ao início.');
    }

    if (inicio.isAfter(DateTime.now()) || fim.isAfter(DateTime.now())) {
      throw Exception('A jornada não pode estar no futuro.');
    }

    return _save(
      idJornada: const Uuid().v4(),
      idVeiculo: idVeiculo,
      inicio: inicio,
      fim: fim,
      kmRodados: kmRodados,
      validateOverlap: true,
    );
  }

  Future<JourneySaveResult> update({
    required String idJornada,
    required String idVeiculo,
    required DateTime inicio,
    required DateTime? fim,
    required double? kmRodados,
  }) async {
    if (fim != null && !fim.isAfter(inicio)) {
      throw Exception('O horário final deve ser posterior ao início.');
    }

    if (inicio.isAfter(DateTime.now()) ||
        (fim != null && fim.isAfter(DateTime.now()))) {
      throw Exception('A jornada não pode estar no futuro.');
    }

    return _save(
      idJornada: idJornada,
      idVeiculo: idVeiculo,
      inicio: inicio,
      fim: fim,
      kmRodados: kmRodados,
      validateOverlap: true,
    );
  }

  Future<JourneySaveResult> updateMileage({
    required Journey journey,
    required double? kmRodados,
  }) {
    return update(
      idJornada: journey.idJornada,
      idVeiculo: journey.idVeiculo,
      inicio: journey.inicio,
      fim: journey.fim,
      kmRodados: kmRodados,
    );
  }

  Future<JourneySaveResult> removeMileage({required Journey journey}) {
    return updateMileage(journey: journey, kmRodados: null);
  }

  Future<bool> delete(String idJornada) async {
    await _localRepository.deleteJornada(idJornada);

    await _localRepository.enqueueDelete(
      entidade: 'jornada',
      registroId: idJornada,
    );

    await trySync();

    return _localRepository.hasPending(
      entidade: 'jornada',
      registroId: idJornada,
    );
  }

  Future<Set<String>> pendingIds() {
    return _localRepository.pendingRecordIds(entidade: 'jornada');
  }

  Future<void> trySync() async {
    try {
      await _syncManager.syncNow();
    } catch (_) {
      // Sem backend:
      // mantém SQLite + outbox.
    }
  }

  Future<JourneySaveResult> _save({
    required String idJornada,
    required String idVeiculo,
    required DateTime inicio,
    required DateTime? fim,
    required double? kmRodados,
    required bool validateOverlap,
  }) async {
    if (kmRodados != null) {
      if (kmRodados <= 0) {
        throw Exception('A quilometragem deve ser maior que zero.');
      }

      if (kmRodados > 999999.99) {
        throw Exception('Quilometragem acima do limite permitido.');
      }

      final rounded = double.parse(kmRodados.toStringAsFixed(2));

      if ((rounded - kmRodados).abs() > 0.000001) {
        throw Exception('A quilometragem aceita no máximo 2 casas decimais.');
      }
    }

    if (validateOverlap) {
      await _validateOverlap(idJornada: idJornada, inicio: inicio, fim: fim);
    }

    final now = DateTime.now().toUtc();

    final payload = <String, dynamic>{
      'id_jornada': idJornada,
      'id_veiculo': idVeiculo,
      'inicio': inicio.toUtc().toIso8601String(),
      'fim': fim?.toUtc().toIso8601String(),
      'km_rodados': kmRodados,
      'atualizado_em': now.toIso8601String(),
    };

    await _localRepository.upsertJornada(payload);

    await _localRepository.enqueueUpsert(
      entidade: 'jornada',
      registroId: idJornada,
      payload: payload,
      atualizadoEm: now,
    );

    await trySync();

    final journey = await findOne(idJornada);

    if (journey == null) {
      throw Exception('Não foi possível carregar a jornada salva.');
    }

    final pending = await _localRepository.hasPending(
      entidade: 'jornada',
      registroId: idJornada,
    );

    return JourneySaveResult(journey: journey, pending: pending);
  }

  Future<void> _validateOverlap({
    required String idJornada,
    required DateTime inicio,
    required DateTime? fim,
  }) async {
    final journeys = await findAll();

    for (final other in journeys) {
      if (other.idJornada == idJornada) {
        continue;
      }

      final otherEnd = other.fim;

      final overlaps =
          (fim == null || other.inicio.isBefore(fim)) &&
          (otherEnd == null || otherEnd.isAfter(inicio));

      if (overlaps) {
        if (other.emAndamento) {
          throw Exception('Já existe uma jornada em andamento.');
        }

        throw Exception(
          'Este horário se sobrepõe a outra jornada já registrada.',
        );
      }
    }
  }

  Journey _journeyFromRow(Map<String, Object?> row) {
    final inicio = DateTime.parse(row['inicio'].toString()).toLocal();

    final fimRaw = row['fim'];

    final fim = fimRaw == null
        ? null
        : DateTime.parse(fimRaw.toString()).toLocal();

    return Journey(
      idJornada: row['id_jornada'].toString(),
      idVeiculo: row['id_veiculo'].toString(),
      inicio: inicio,
      fim: fim,
      kmRodados: (row['km_rodados'] as num?)?.toDouble(),
      duracaoMinutos: fim == null ? null : fim.difference(inicio).inMinutes,
      veiculoMarca: row['veiculo_marca']?.toString(),
      veiculoModelo: row['veiculo_modelo']?.toString(),
      veiculoPlaca: row['veiculo_placa']?.toString(),
    );
  }
}
