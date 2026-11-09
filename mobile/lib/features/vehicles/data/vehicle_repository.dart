import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';
import '../../sync/data/sync_local_repository.dart';
import '../../sync/services/sync_manager.dart';
import 'create_vehicle_request.dart';
import 'update_vehicle_request.dart';
import 'vehicle.dart';

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
  static const Object _unset = Object();

  final SyncLocalRepository _localRepository;

  final SyncManager _syncManager;

  VehicleRepository({
    required SyncLocalRepository localRepository,
    required SyncManager syncManager,
  }) : _localRepository = localRepository,
       _syncManager = syncManager;

  Future<List<Vehicle>> findAll() {
    return _findCached(active: true);
  }

  Future<List<Vehicle>> findInactive() {
    return _findCached(active: false);
  }

  Future<Vehicle> create(CreateVehicleRequest request) async {
    final marca = request.marca.trim();

    final modelo = request.modelo.trim();

    final combustivel = request.combustivel.trim();

    final placa = _cleanPlate(request.placa);

    _validateVehicle(
      marca: marca,
      modelo: modelo,
      ano: request.ano,
      combustivel: combustivel,
      consumoMedio: request.consumoMedio,
      placa: placa,
    );

    await _validateLocalPlate(placa);

    final userId = AppDatabase.instance.activeUserId;

    if (userId == null || userId.isEmpty) {
      throw Exception('Nenhum usuário ativo para salvar o veículo.');
    }

    final id = const Uuid().v4();

    final now = DateTime.now().toUtc();

    final state = <String, dynamic>{
      'id_veiculo': id,
      'id_usuario': userId,
      'marca': marca,
      'modelo': modelo,
      'ano': request.ano,
      'combustivel': combustivel,
      'consumo_medio': _round2(request.consumoMedio),
      'placa': placa,
      'principal': false,
      'ativo': true,
      'data_atualizacao': now.toIso8601String(),
    };

    await _saveState(state, now);

    await trySync();

    return Vehicle.fromJson(state);
  }

  Future<Vehicle> update(String id, UpdateVehicleRequest request) async {
    final current = await _findOne(id);

    if (!current.ativo) {
      throw Exception(
        'Este veículo está removido. '
        'Reative-o antes de alterá-lo.',
      );
    }

    final marca = (request.marca ?? current.marca).trim();

    final modelo = (request.modelo ?? current.modelo).trim();

    final ano = request.ano ?? current.ano;

    final combustivel = (request.combustivel ?? current.combustivel).trim();

    final consumoMedio = request.consumoMedio ?? current.consumoMedio;

    final placa = _cleanPlate(request.placa);

    _validateVehicle(
      marca: marca,
      modelo: modelo,
      ano: ano,
      combustivel: combustivel,
      consumoMedio: consumoMedio,
      placa: placa,
    );

    await _validateLocalPlate(placa, ignoreId: id);

    final now = DateTime.now().toUtc();

    final state = _vehicleState(
      current,
      marca: marca,
      modelo: modelo,
      ano: ano,
      combustivel: combustivel,
      consumoMedio: _round2(consumoMedio),
      placa: placa,
      atualizadoEm: now,
    );

    await _saveState(state, now);

    await trySync();

    return Vehicle.fromJson(state);
  }

  Future<String> delete(String id) async {
    final current = await _findOne(id);

    final now = DateTime.now().toUtc();

    final state = _vehicleState(
      current,
      ativo: false,
      principal: false,
      atualizadoEm: now,
    );

    await _saveState(state, now);

    await trySync();

    return 'Veículo removido com sucesso.';
  }

  Future<String> setPrincipal(String id) async {
    final selected = await _findOne(id);

    if (!selected.ativo) {
      throw Exception(
        'Este veículo está removido. '
        'Reative-o antes de defini-lo como principal.',
      );
    }

    final all = await _findCached();

    // Desmarca o principal anterior localmente
    // e também atualiza sua outbox.
    for (final vehicle in all) {
      if (vehicle.idVeiculo == id || !vehicle.principal) {
        continue;
      }

      final now = DateTime.now().toUtc();

      final state = _vehicleState(vehicle, principal: false, atualizadoEm: now);

      await _saveState(state, now);
    }

    if (!selected.principal) {
      final now = DateTime.now().toUtc();

      final state = _vehicleState(selected, principal: true, atualizadoEm: now);

      await _saveState(state, now);
    }

    await trySync();

    return 'Veículo definido como principal.';
  }

  Future<Vehicle> reactivate(String id) async {
    final current = await _findOne(id);

    if (current.ativo) {
      throw Exception('Este veículo já está ativo.');
    }

    final now = DateTime.now().toUtc();

    final state = _vehicleState(
      current,
      ativo: true,
      principal: false,
      atualizadoEm: now,
    );

    await _saveState(state, now);

    await trySync();

    return Vehicle.fromJson(state);
  }

  Future<Set<String>> pendingIds() {
    return _localRepository.pendingRecordIds(entidade: 'veiculo');
  }

  Future<Map<String, String>> attentionReasons() async {
    final items = await _localRepository.findNeedsAttention();

    return {
      for (final item in items)
        if (item.entidade == 'veiculo')
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

  Future<List<Vehicle>> _findCached({bool? active}) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      DatabaseTables.veiculosCache,
      where: active == null ? null : 'ativo = ?',
      whereArgs: active == null ? null : [active ? 1 : 0],
      orderBy:
          'principal DESC, '
          'ativo DESC, '
          'marca ASC, '
          'modelo ASC',
    );

    return rows.map(_vehicleFromRow).toList();
  }

  Vehicle _vehicleFromRow(Map<String, Object?> row) {
    final rawJson = row['raw_json']?.toString();

    if (rawJson != null && rawJson.isNotEmpty) {
      final decoded = jsonDecode(rawJson);

      if (decoded is Map) {
        final json = Map<String, dynamic>.from(decoded);

        json['id_veiculo'] = row['id_veiculo'].toString();

        json['marca'] = row['marca']?.toString() ?? json['marca'];

        json['modelo'] = row['modelo']?.toString() ?? json['modelo'];

        json['placa'] = row['placa']?.toString();

        json['ativo'] = (row['ativo'] as num?)?.toInt() == 1;

        json['principal'] = (row['principal'] as num?)?.toInt() == 1;

        return Vehicle.fromJson(json);
      }
    }

    throw Exception('Dados locais do veículo estão incompletos.');
  }

  Future<Vehicle> _findOne(String id) async {
    final all = await _findCached();

    for (final vehicle in all) {
      if (vehicle.idVeiculo == id) {
        return vehicle;
      }
    }

    throw Exception('Veículo não encontrado.');
  }

  Future<void> _saveState(Map<String, dynamic> state, DateTime now) async {
    await _localRepository.upsertVeiculo(state);

    await _localRepository.enqueueUpsert(
      entidade: 'veiculo',
      registroId: state['id_veiculo'].toString(),
      payload: _syncPayload(state, now),
      atualizadoEm: now,
    );
  }

  Map<String, dynamic> _syncPayload(Map<String, dynamic> state, DateTime now) {
    return {
      'id_veiculo': state['id_veiculo'],
      'marca': state['marca'],
      'modelo': state['modelo'],
      'ano': state['ano'],
      'combustivel': state['combustivel'],
      'consumo_medio': state['consumo_medio'],
      'placa': state['placa'],
      'ativo': state['ativo'],
      'principal': state['ativo'] == true ? state['principal'] == true : false,

      // UTC + Z
      'atualizado_em': now.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _vehicleState(
    Vehicle current, {
    String? marca,
    String? modelo,
    int? ano,
    String? combustivel,
    double? consumoMedio,
    Object? placa = _unset,
    bool? ativo,
    bool? principal,
    required DateTime atualizadoEm,
  }) {
    final effectiveActive = ativo ?? current.ativo;

    final effectivePrincipal = effectiveActive
        ? (principal ?? current.principal)
        : false;

    return {
      'id_veiculo': current.idVeiculo,
      'id_usuario': current.idUsuario,
      'marca': marca ?? current.marca,
      'modelo': modelo ?? current.modelo,
      'ano': ano ?? current.ano,
      'combustivel': combustivel ?? current.combustivel,
      'consumo_medio': consumoMedio ?? current.consumoMedio,
      'placa': identical(placa, _unset) ? current.placa : placa as String?,
      'principal': effectivePrincipal,
      'ativo': effectiveActive,
      'data_atualizacao': atualizadoEm.toUtc().toIso8601String(),
    };
  }

  Future<void> _validateLocalPlate(String? plate, {String? ignoreId}) async {
    if (plate == null) {
      return;
    }

    final vehicles = await _findCached();

    for (final vehicle in vehicles) {
      if (vehicle.idVeiculo == ignoreId) {
        continue;
      }

      if ((vehicle.placa ?? '').toUpperCase() != plate.toUpperCase()) {
        continue;
      }

      if (!vehicle.ativo) {
        throw InactiveVehicleConflict(
          message: 'Você já tem um veículo removido com essa placa.',
          vehicleId: vehicle.idVeiculo,
        );
      }

      throw Exception('Já existe um veículo cadastrado com essa placa.');
    }
  }

  void _validateVehicle({
    required String marca,
    required String modelo,
    required int ano,
    required String combustivel,
    required double consumoMedio,
    required String? placa,
  }) {
    if (marca.isEmpty || marca.length > 50) {
      throw Exception(
        'A marca é obrigatória e deve ter no máximo 50 caracteres.',
      );
    }

    if (modelo.isEmpty || modelo.length > 50) {
      throw Exception(
        'O modelo é obrigatório e deve ter no máximo 50 caracteres.',
      );
    }

    if (ano < 1950 || ano > 2100) {
      throw Exception('O ano deve estar entre 1950 e 2100.');
    }

    if (combustivel.isEmpty || combustivel.length > 30) {
      throw Exception(
        'O combustível é obrigatório e deve ter no máximo 30 caracteres.',
      );
    }

    if (consumoMedio <= 0 || consumoMedio > 999.99) {
      throw Exception(
        'O consumo médio deve ser maior que zero e no máximo 999,99.',
      );
    }

    if ((consumoMedio - _round2(consumoMedio)).abs() > 0.000001) {
      throw Exception('O consumo médio aceita no máximo 2 casas decimais.');
    }

    if (placa != null && placa.length > 10) {
      throw Exception('A placa deve ter no máximo 10 caracteres.');
    }
  }

  String? _cleanPlate(String? value) {
    final clean = value?.trim().toUpperCase();

    if (clean == null || clean.isEmpty) {
      return null;
    }

    return clean;
  }

  double _round2(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}
