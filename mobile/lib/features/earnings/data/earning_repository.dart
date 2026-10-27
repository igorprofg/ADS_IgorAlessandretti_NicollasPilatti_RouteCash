import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';
import '../../sync/data/sync_local_repository.dart';
import '../../sync/services/sync_manager.dart';
import 'earning.dart';

class EarningVehicleOption {
  final String idVeiculo;
  final String marca;
  final String modelo;
  final bool principal;

  const EarningVehicleOption({
    required this.idVeiculo,
    required this.marca,
    required this.modelo,
    required this.principal,
  });

  String get nome {
    return '$marca $modelo'.trim();
  }
}

class EarningPlatformOption {
  final String idPlataforma;
  final String nome;

  const EarningPlatformOption({
    required this.idPlataforma,
    required this.nome,
  });
}

class EarningReferenceData {
  final List<EarningVehicleOption> vehicles;
  final List<EarningPlatformOption> platforms;

  const EarningReferenceData({
    required this.vehicles,
    required this.platforms,
  });
}

class EarningRepository {
  final SyncLocalRepository _localRepository;
  final SyncManager _syncManager;

  EarningRepository({
    required SyncLocalRepository localRepository,
    required SyncManager syncManager,
  })  : _localRepository = localRepository,
        _syncManager = syncManager;

  Future<List<Earning>> findAll() async {
    final db = await AppDatabase.instance.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        g.id_ganho,
        g.id_veiculo,
        g.id_plataforma,
        g.valor,
        g.data,
        g.observacao,
        g.atualizado_em,
        v.marca AS veiculo_marca,
        v.modelo AS veiculo_modelo,
        p.nome AS plataforma_nome
      FROM ${DatabaseTables.ganhosLocal} g
      LEFT JOIN ${DatabaseTables.veiculosCache} v
        ON v.id_veiculo = g.id_veiculo
      LEFT JOIN ${DatabaseTables.plataformasCache} p
        ON p.id_plataforma = g.id_plataforma
      ORDER BY g.data DESC, g.atualizado_em DESC
      ''',
    );

    return rows.map(
      (row) {
        return Earning.fromJson(
          {
            'id_ganho':
                row['id_ganho'].toString(),
            'id_veiculo':
                row['id_veiculo'].toString(),
            'id_plataforma':
                row['id_plataforma'].toString(),
            'valor':
                (row['valor'] as num).toDouble(),
            'data':
                row['data'].toString(),
            'observacao':
                row['observacao']?.toString(),
            'veiculo': {
              'marca':
                  row['veiculo_marca']?.toString(),
              'modelo':
                  row['veiculo_modelo']?.toString(),
            },
            'plataforma': {
              'nome':
                  row['plataforma_nome']?.toString(),
            },
          },
        );
      },
    ).toList();
  }

  Future<EarningReferenceData>
      loadReferenceData() async {
    await trySync();

    final db = await AppDatabase.instance.database;

    final vehicleRows = await db.query(
      DatabaseTables.veiculosCache,
      columns: [
        'id_veiculo',
        'marca',
        'modelo',
        'principal',
      ],
      where: 'ativo = ?',
      whereArgs: [1],
      orderBy: 'principal DESC, marca ASC, modelo ASC',
    );

    final platformRows = await db.query(
      DatabaseTables.plataformasCache,
      columns: [
        'id_plataforma',
        'nome',
      ],
      where: 'ativa = ?',
      whereArgs: [1],
      orderBy: 'padrao DESC, nome ASC',
    );

    final vehicles = vehicleRows
        .map(
          (row) => EarningVehicleOption(
            idVeiculo:
                row['id_veiculo'].toString(),
            marca:
                row['marca']?.toString() ?? '',
            modelo:
                row['modelo']?.toString() ?? '',
            principal:
                (row['principal'] as num?)
                        ?.toInt() ==
                    1,
          ),
        )
        .toList();

    final platforms = platformRows
        .map(
          (row) => EarningPlatformOption(
            idPlataforma:
                row['id_plataforma'].toString(),
            nome:
                row['nome']?.toString() ?? '',
          ),
        )
        .toList();

    return EarningReferenceData(
      vehicles: vehicles,
      platforms: platforms,
    );
  }

  Future<bool> save({
    required String idGanho,
    required String idVeiculo,
    required String idPlataforma,
    required double valor,
    required DateTime data,
    required String? observacao,
  }) async {
    final now = DateTime.now().toUtc();

    final payload = <String, dynamic>{
      'id_ganho': idGanho,
      'id_veiculo': idVeiculo,
      'id_plataforma': idPlataforma,
      'valor': valor,
      'data': _formatDate(data),
      'observacao': _cleanObservation(
        observacao,
      ),
      'atualizado_em':
          now.toIso8601String(),
    };

    await _localRepository.upsertGanho(
      payload,
    );

    await _localRepository.enqueueUpsert(
      entidade: 'ganho',
      registroId: idGanho,
      payload: payload,
      atualizadoEm: now,
    );

    await trySync();

    return _localRepository.hasPending(
      entidade: 'ganho',
      registroId: idGanho,
    );
  }

  Future<bool> delete(
    String idGanho,
  ) async {
    await _localRepository.deleteGanho(
      idGanho,
    );

    await _localRepository.enqueueDelete(
      entidade: 'ganho',
      registroId: idGanho,
    );

    await trySync();

    return _localRepository.hasPending(
      entidade: 'ganho',
      registroId: idGanho,
    );
  }

  Future<Set<String>> pendingIds() {
    return _localRepository.pendingRecordIds(
      entidade: 'ganho',
    );
  }

  Future<void> trySync() async {
    try {
      await _syncManager.syncNow();
    } catch (_) {
      // Offline ou servidor indisponível:
      // o dado continua salvo localmente e na outbox.
    }
  }

  String _formatDate(
    DateTime date,
  ) {
    final year =
        date.year.toString().padLeft(4, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final day =
        date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String? _cleanObservation(
    String? value,
  ) {
    final clean = value?.trim();

    if (clean == null ||
        clean.isEmpty) {
      return null;
    }

    return clean;
  }
}
