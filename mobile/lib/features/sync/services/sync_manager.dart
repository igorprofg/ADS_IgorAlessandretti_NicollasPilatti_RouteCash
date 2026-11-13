import '../data/sync_item_result.dart';
import '../data/sync_local_repository.dart';
import '../data/sync_outbox_item.dart';
import '../data/sync_repository.dart';
import 'package:flutter/foundation.dart';

class SyncManager {
  final SyncRepository remoteRepository;
  final SyncLocalRepository localRepository;

  bool _running = false;

  SyncManager({required this.remoteRepository, required this.localRepository});

  bool get running => _running;

  Future<void> syncNow() async {
    if (_running) {
      return;
    }

    _running = true;

    try {
      // 1ª etapa:
      // envia tudo que já está pendente.
      await _sendPending();

      // Atualiza os caches com o estado
      // realmente existente no servidor.
      await _downloadAndReconcile();

      // Alguns itens podem ter ficado em atenção
      // porque uma dependência ainda não existia.
      //
      // Exemplo:
      // veículo falhou -> ganho falhou.
      //
      // Se o veículo agora já está confirmado pelo
      // snapshot, o ganho pode voltar para pendente.
      final requeued = await localRepository
          .requeueResolvedDependencyAttention();

      if (requeued > 0) {
        debugPrint(
          '[SYNC] $requeued item(ns) '
          'voltaram de atenção para pendente '
          'após resolução das dependências.',
        );

        // 2ª etapa:
        // tenta imediatamente os itens recuperados.
        await _sendPending();

        // E atualiza novamente o SQLite com
        // o resultado final do servidor.
        await _downloadAndReconcile();
      }
    } finally {
      _running = false;
    }
  }

  Future<void> downloadAndReconcile() async {
    if (_running) {
      return;
    }

    _running = true;

    try {
      await _downloadAndReconcile();
    } finally {
      _running = false;
    }
  }

  Future<void> _sendPending() async {
    final attempted = <String>{};

    while (true) {
      final pending = await localRepository.findPending();

      final available = pending
          .where((item) => !attempted.contains(_key(item)))
          .toList();

      if (available.isEmpty) {
        return;
      }

      // Ordem obrigatória do RF11.
      final vehicles = _takeEntity(
        available,
        entidade: 'veiculo',
        operacao: 'upsert',
      );

      final platforms = _takeEntity(
        available,
        entidade: 'plataforma',
        operacao: 'upsert',
      );

      final gains = _takeEntity(
        available,
        entidade: 'ganho',
        operacao: 'upsert',
      );

      final expenses = _takeEntity(
        available,
        entidade: 'despesa',
        operacao: 'upsert',
      );

      final journeys = _takeEntity(
        available,
        entidade: 'jornada',
        operacao: 'upsert',
      );

      // Veículo e plataforma NUNCA entram
      // em exclusoes.
      final deletions = available
          .where(
            (item) =>
                item.operacao == 'delete' &&
                (item.entidade == 'ganho' ||
                    item.entidade == 'despesa' ||
                    item.entidade == 'jornada'),
          )
          .take(50)
          .toList();

      if (vehicles.isEmpty &&
          platforms.isEmpty &&
          gains.isEmpty &&
          expenses.isEmpty &&
          journeys.isEmpty &&
          deletions.isEmpty) {
        return;
      }

      final sentItems = [
        ...vehicles,
        ...platforms,
        ...gains,
        ...expenses,
        ...journeys,
        ...deletions,
      ];

      attempted.addAll(sentItems.map(_key));

      final results = await remoteRepository.enviar(
        veiculos: vehicles.map((item) => item.payload!).toList(),
        plataformas: platforms.map((item) => item.payload!).toList(),
        ganhos: gains.map((item) => item.payload!).toList(),
        despesas: expenses.map((item) => item.payload!).toList(),
        jornadas: journeys.map((item) => item.payload!).toList(),
        exclusoes: deletions
            .map((item) => {'entidade': item.entidade, 'id': item.registroId})
            .toList(),
      );

      for (final result in results) {
        debugPrint(
          '[SYNC] '
          'entidade=${result.entidade} '
          'id=${result.id} '
          'status=${result.status} '
          'codigo=${result.codigo} '
          'motivo=${result.motivo}',
        );
      }

      for (final result in results) {
        await _applyResult(result);
      }

      final processedIds = sentItems.map(_key).toSet();

      final resultIds = results
          .where((result) => result.id != null)
          .map((result) => '${result.entidade}:${result.id}')
          .toSet();

      final missing = processedIds.difference(resultIds);

      if (missing.isNotEmpty) {
        throw Exception(
          'O servidor não retornou resultado '
          'para todos os itens enviados.',
        );
      }
    }
  }

  List<SyncOutboxItem> _takeEntity(
    List<SyncOutboxItem> items, {
    required String entidade,
    required String operacao,
  }) {
    return items
        .where(
          (item) =>
              item.entidade == entidade &&
              item.operacao == operacao &&
              item.payload != null,
        )
        .take(50)
        .toList();
  }

  String _key(SyncOutboxItem item) {
    return '${item.entidade}:'
        '${item.registroId}';
  }

  Future<void> _applyResult(SyncItemResult result) async {
    final id = result.id;

    if (id == null) {
      return;
    }

    if (result.status == 'ok' || result.status == 'ignorado') {
      await localRepository.removeOutbox(
        entidade: result.entidade,
        registroId: id,
      );

      return;
    }

    if (result.codigo == 'ERRO_INTERNO') {
      await localRepository.incrementAttempts(
        entidade: result.entidade,
        registroId: id,
        motivoErro: result.motivo,
      );

      return;
    }

    const attentionCodes = {'VALIDACAO', 'NAO_ENCONTRADO', 'CONFLITO'};

    if (attentionCodes.contains(result.codigo)) {
      await localRepository.markNeedsAttention(
        entidade: result.entidade,
        registroId: id,
        codigo: result.codigo ?? 'ERRO',
        motivo: result.motivo ?? 'A sincronização precisa de atenção.',
      );

      return;
    }

    await localRepository.markNeedsAttention(
      entidade: result.entidade,
      registroId: id,
      codigo: result.codigo ?? 'ERRO',
      motivo: result.motivo ?? 'Erro não identificado durante a sincronização.',
    );
  }

  Future<void> _downloadAndReconcile() async {
    final snapshot = await remoteRepository.baixar();

    await localRepository.reconcileSnapshot(snapshot);
  }
}
