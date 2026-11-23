import 'package:flutter/foundation.dart';

import '../data/sync_assinatura_exception.dart';
import '../data/sync_item_result.dart';
import '../data/sync_local_repository.dart';
import '../data/sync_outbox_item.dart';
import '../data/sync_repository.dart';

class SyncManager {
  final SyncRepository remoteRepository;
  final SyncLocalRepository localRepository;

  bool _running = false;

  SyncManager({required this.remoteRepository, required this.localRepository});

  bool get running => _running;

  // ------------------------------------------------------------
  // SINCRONIZAÇÃO COMPLETA
  // ------------------------------------------------------------

  Future<void> syncNow() async {
    if (_running) {
      debugPrint('[SYNC] Sincronização já está em andamento.');
      return;
    }

    _running = true;

    try {
      debugPrint('[SYNC] Iniciando sincronização.');

      // 1ª etapa:
      // Envia os registros pendentes para o servidor.
      await _sendPending();

      // 2ª etapa:
      // Baixa o snapshot e reconcilia com o SQLite.
      await _downloadAndReconcile();

      // 3ª etapa:
      // Verifica se alguma dependência foi resolvida.
      //
      // Exemplo:
      // Um ganho estava em atenção porque o veículo
      // ainda não existia no servidor.
      //
      // Se o veículo agora estiver confirmado no snapshot,
      // o ganho poderá voltar para pendente.

      final requeued = await localRepository
          .requeueResolvedDependencyAttention();

      if (requeued > 0) {
        debugPrint(
          '[SYNC] $requeued item(ns) voltaram '
          'de atenção para pendente.',
        );

        // 4ª etapa:
        // Tenta enviar os itens recuperados.
        await _sendPending();

        // 5ª etapa:
        // Atualiza novamente o SQLite com
        // o estado final do servidor.
        await _downloadAndReconcile();
      }

      debugPrint('[SYNC] Sincronização concluída.');
    } on SyncAssinaturaException {
      // O backend recusou o envio porque
      // não existe assinatura ativa e válida.
      //
      // Nenhum resultado desse envio será aplicado.
      // Os itens não confirmados permanecem
      // armazenados na sync_outbox.
      //
      // A exceção será propagada para que
      // o SyncAutoService possa pausar
      // novas tentativas automáticas.

      debugPrint(
        '[SYNC] Sincronização bloqueada: '
        'assinatura inativa.',
      );

      debugPrint(
        '[SYNC] Registros não confirmados '
        'permanecem pendentes no SQLite.',
      );

      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[SYNC] Erro durante a sincronização: $e');

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } finally {
      _running = false;
    }
  }

  // ------------------------------------------------------------
  // DOWNLOAD E RECONCILIAÇÃO
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // ENVIO DA OUTBOX
  // ------------------------------------------------------------

  Future<void> _sendPending() async {
    // Evita tentar o mesmo item repetidamente
    // durante uma única execução.
    final attempted = <String>{};

    while (true) {
      final pending = await localRepository.findPending();

      final available = pending
          .where((item) => !attempted.contains(_key(item)))
          .toList();

      if (available.isEmpty) {
        return;
      }

      // Ordem obrigatória do RF11:
      // veículos, plataformas, ganhos,
      // despesas, jornadas e exclusões.

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

      // Somente ganhos, despesas e jornadas
      // podem entrar como exclusões.

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

      debugPrint(
        '[SYNC] Enviando ${sentItems.length} '
        'item(ns) pendente(s).',
      );

      // Se o servidor retornar HTTP 403
      // com ASSINATURA_NECESSARIA,
      // o SyncRepository lança
      // SyncAssinaturaException.
      //
      // Assim, o processamento será interrompido
      // antes de remover qualquer item
      // desse lote da outbox.

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

      // Registra os resultados retornados
      // pelo servidor.

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

      // Confere se todos os itens enviados
      // receberam uma resposta.
      //
      // Essa validação ocorre ANTES de
      // modificar a outbox.

      final processedIds = sentItems.map(_key).toSet();

      final resultIds = results
          .where((result) => result.id != null)
          .map((result) => '${result.entidade}:${result.id}')
          .toSet();

      final missing = processedIds.difference(resultIds);

      if (missing.isNotEmpty) {
        throw Exception(
          'O servidor não retornou resultado '
          'para todos os itens enviados: '
          '${missing.join(', ')}',
        );
      }

      // Aplica os resultados somente depois
      // que a resposta foi validada.

      for (final result in results) {
        await _applyResult(result);
      }
    }
  }

  // ------------------------------------------------------------
  // SELEÇÃO DOS ITENS
  // ------------------------------------------------------------

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
    return '${item.entidade}:${item.registroId}';
  }

  // ------------------------------------------------------------
  // PROCESSAMENTO DOS RESULTADOS
  // ------------------------------------------------------------

  Future<void> _applyResult(SyncItemResult result) async {
    final id = result.id;

    if (id == null) {
      return;
    }

    // O servidor confirmou que o item
    // foi processado ou já estava aplicado.

    if (result.status == 'ok' || result.status == 'ignorado') {
      await localRepository.removeOutbox(
        entidade: result.entidade,
        registroId: id,
      );

      return;
    }

    // Erro interno:
    // mantém pendente e registra a tentativa.

    if (result.codigo == 'ERRO_INTERNO') {
      await localRepository.incrementAttempts(
        entidade: result.entidade,
        registroId: id,
        motivoErro: result.motivo,
      );

      return;
    }

    // Erros que exigem atenção.

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

    // Erros desconhecidos:
    // preserva o item e sinaliza atenção.

    await localRepository.markNeedsAttention(
      entidade: result.entidade,
      registroId: id,
      codigo: result.codigo ?? 'ERRO',
      motivo: result.motivo ?? 'Erro não identificado durante a sincronização.',
    );
  }

  // ------------------------------------------------------------
  // SNAPSHOT
  // ------------------------------------------------------------

  Future<void> _downloadAndReconcile() async {
    final snapshot = await remoteRepository.baixar();

    await localRepository.reconcileSnapshot(snapshot);

    debugPrint('[SYNC] Snapshot recebido e reconciliado.');
  }
}
