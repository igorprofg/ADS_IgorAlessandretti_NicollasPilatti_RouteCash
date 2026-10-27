import '../data/sync_item_result.dart';
import '../data/sync_local_repository.dart';
import '../data/sync_outbox_item.dart';
import '../data/sync_repository.dart';

class SyncManager {
  final SyncRepository remoteRepository;
  final SyncLocalRepository localRepository;

  bool _running = false;

  SyncManager({
    required this.remoteRepository,
    required this.localRepository,
  });

  bool get running => _running;

  Future<void> syncNow() async {
    if (_running) {
      return;
    }

    _running = true;

    try {
      await _sendPending();
      await _downloadAndReconcile();
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
      final pending =
          await localRepository.findPending();

      final available = pending
          .where(
            (item) =>
                !attempted.contains(
                  _key(item),
                ),
          )
          .toList();

      if (available.isEmpty) {
        return;
      }

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

      final deletions = available
          .where(
            (item) =>
                item.operacao == 'delete',
          )
          .take(50)
          .toList();

      if (gains.isEmpty &&
          expenses.isEmpty &&
          journeys.isEmpty &&
          deletions.isEmpty) {
        return;
      }

      final sentItems = [
        ...gains,
        ...expenses,
        ...journeys,
        ...deletions,
      ];

      attempted.addAll(
        sentItems.map(_key),
      );

      final results =
          await remoteRepository.enviar(
        ganhos: gains
            .map((item) => item.payload!)
            .toList(),
        despesas: expenses
            .map((item) => item.payload!)
            .toList(),
        jornadas: journeys
            .map((item) => item.payload!)
            .toList(),
        exclusoes: deletions
            .map(
              (item) => {
                'entidade':
                    item.entidade,
                'id':
                    item.registroId,
              },
            )
            .toList(),
      );

      for (final result in results) {
        await _applyResult(
          result,
        );
      }

      final processedIds =
          sentItems.map(_key).toSet();

      final resultIds = results
          .where(
            (result) =>
                result.id != null,
          )
          .map(
            (result) =>
                '${result.entidade}:${result.id}',
          )
          .toSet();

      final missing =
          processedIds.difference(
        resultIds,
      );

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

  String _key(
    SyncOutboxItem item,
  ) {
    return '${item.entidade}:${item.registroId}';
  }

  Future<void> _applyResult(
    SyncItemResult result,
  ) async {
    final id = result.id;

    if (id == null) {
      return;
    }

    if (result.status == 'ok' ||
        result.status == 'ignorado') {
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

    final attentionCodes = {
      'VALIDACAO',
      'NAO_ENCONTRADO',
      'CONFLITO',
    };

    if (attentionCodes.contains(
      result.codigo,
    )) {
      await localRepository.markNeedsAttention(
        entidade: result.entidade,
        registroId: id,
        codigo:
            result.codigo ??
            'ERRO',
        motivo:
            result.motivo ??
            'A sincronização precisa de atenção.',
      );

      return;
    }

    await localRepository.markNeedsAttention(
      entidade: result.entidade,
      registroId: id,
      codigo:
          result.codigo ??
          'ERRO',
      motivo:
          result.motivo ??
          'Erro não identificado durante a sincronização.',
    );
  }

  Future<void> _downloadAndReconcile() async {
    final snapshot =
        await remoteRepository.baixar();

    await localRepository.reconcileSnapshot(
      snapshot,
    );
  }
}
