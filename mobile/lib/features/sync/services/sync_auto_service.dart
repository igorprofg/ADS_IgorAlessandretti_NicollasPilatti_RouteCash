import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../data/sync_assinatura_exception.dart';
import '../data/sync_local_repository.dart';
import 'sync_manager.dart';

class SyncAutoService with WidgetsBindingObserver {
  final SyncManager syncManager;
  final SyncLocalRepository localRepository;
  final Connectivity connectivity;

  SyncAutoService({
    required this.syncManager,
    required this.localRepository,
    Connectivity? connectivity,
  }) : connectivity = connectivity ?? Connectivity();

  // ------------------------------------------------------------
  // CONFIGURAÇÕES
  // ------------------------------------------------------------

  static const Duration retryInterval = Duration(seconds: 15);

  static const Duration refreshInterval = Duration(minutes: 5);

  // Quando a assinatura estiver inativa,
  // não tentamos enviar a cada 15 segundos.
  //
  // Uma nova tentativa será permitida após
  // 5 minutos, para detectar uma reativação.
  static const Duration assinaturaRetryInterval = Duration(minutes: 5);

  // ------------------------------------------------------------
  // EVENTOS
  // ------------------------------------------------------------

  final StreamController<void> _syncedController =
      StreamController<void>.broadcast();

  Stream<void> get onSynced => _syncedController.stream;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Timer? _retryTimer;
  Timer? _refreshTimer;

  // ------------------------------------------------------------
  // ESTADOS
  // ------------------------------------------------------------

  bool _started = false;
  bool _syncing = false;
  bool _disposed = false;

  bool _assinaturaBloqueada = false;

  DateTime? _proximaTentativaAssinatura;

  bool get syncing => _syncing;

  bool get assinaturaBloqueada => _assinaturaBloqueada;

  // ------------------------------------------------------------
  // INICIALIZAÇÃO
  // ------------------------------------------------------------

  void start() {
    if (_started || _disposed) {
      return;
    }

    _started = true;

    WidgetsBinding.instance.addObserver(this);

    debugPrint('[AUTOSYNC] Serviço iniciado.');

    // Detecta mudanças de conectividade.
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (_disposed) {
        return;
      }

      final hasNetwork = !results.contains(ConnectivityResult.none);

      if (hasNetwork) {
        debugPrint('[AUTOSYNC] Conectividade disponível.');

        unawaited(tryNow(forceFullSync: true));
      }
    });

    // Tentativa frequente para pendências.
    // Continua detectando quando o NestJS
    // volta a responder.
    _retryTimer = Timer.periodic(retryInterval, (_) {
      unawaited(tryNow());
    });

    // Atualização periódica do snapshot.
    // Também funciona como oportunidade
    // de verificar uma assinatura reativada.
    _refreshTimer = Timer.periodic(refreshInterval, (_) {
      unawaited(tryNow(forceFullSync: true));
    });

    // Primeira sincronização ao iniciar.
    unawaited(tryNow(forceFullSync: true));
  }

  // ------------------------------------------------------------
  // SINCRONIZAÇÃO AUTOMÁTICA
  // ------------------------------------------------------------

  Future<bool> tryNow({bool forceFullSync = false}) async {
    if (_disposed || !_started || _syncing) {
      return false;
    }

    // Evita múltiplas execuções simultâneas.
    // O bloqueio é ativado antes de qualquer
    // operação assíncrona.
    _syncing = true;

    try {
      // Verifica se a assinatura está bloqueada.
      if (_assinaturaBloqueada) {
        final agora = DateTime.now();

        final proxima = _proximaTentativaAssinatura;

        if (proxima != null && agora.isBefore(proxima)) {
          return false;
        }

        debugPrint(
          '[AUTOSYNC] Verificando se a '
          'assinatura foi reativada.',
        );
      }

      // Se não é uma sincronização completa,
      // só executa quando existem pendências.
      if (!forceFullSync) {
        final pending = await localRepository.findPending(limit: 1);

        if (pending.isEmpty) {
          return false;
        }
      }

      await syncManager.syncNow();

      // A sincronização foi concluída.
      // Se a assinatura estava bloqueada,
      // o acesso já foi restabelecido.
      if (_assinaturaBloqueada) {
        debugPrint(
          '[AUTOSYNC] Assinatura reativada. '
          'Sincronização liberada.',
        );
      }

      _assinaturaBloqueada = false;
      _proximaTentativaAssinatura = null;

      if (!_disposed && !_syncedController.isClosed) {
        _syncedController.add(null);
      }

      return true;
    } on SyncAssinaturaException {
      // O backend retornou:
      // HTTP 403 - ASSINATURA_NECESSARIA.
      //
      // Nenhum item da outbox é removido aqui.
      // Não executamos reconciliação adicional.
      //
      // Suspendemos as tentativas frequentes
      // e permitimos nova verificação
      // após o intervalo configurado.

      _assinaturaBloqueada = true;

      _proximaTentativaAssinatura = DateTime.now().add(assinaturaRetryInterval);

      debugPrint(
        '[AUTOSYNC] Assinatura inativa. '
        'Envios temporariamente pausados.',
      );

      debugPrint(
        '[AUTOSYNC] Os registros continuam '
        'armazenados no SQLite.',
      );

      return false;
    } catch (e) {
      // Falha de rede, backend indisponível
      // ou outro erro inesperado.
      //
      // Se a assinatura estava bloqueada,
      // não consideramos que ela foi reativada.
      if (_assinaturaBloqueada) {
        _proximaTentativaAssinatura = DateTime.now().add(
          assinaturaRetryInterval,
        );
      }

      debugPrint('[AUTOSYNC] Sincronização não concluída: $e');

      return false;
    } finally {
      _syncing = false;
    }
  }

  // ------------------------------------------------------------
  // RETOMADA EXPLÍCITA
  // ------------------------------------------------------------

  // Pode ser chamado após a confirmação
  // de reativação da assinatura pelo backend.
  //
  // Não presume que a assinatura está ativa:
  // apenas libera uma tentativa de sincronização.
  Future<bool> verificarAposReativacao() async {
    if (_disposed || !_started || _syncing) {
      return false;
    }

    _proximaTentativaAssinatura = null;

    debugPrint(
      '[AUTOSYNC] Nova verificação solicitada '
      'após reativação da assinatura.',
    );

    return tryNow(forceFullSync: true);
  }

  // ------------------------------------------------------------
  // CICLO DE VIDA DO APLICATIVO
  // ------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || !_started) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      debugPrint('[AUTOSYNC] Aplicativo retomado.');

      unawaited(tryNow(forceFullSync: true));
    }
  }

  // ------------------------------------------------------------
  // ENCERRAMENTO
  // ------------------------------------------------------------

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    if (_started) {
      _started = false;

      WidgetsBinding.instance.removeObserver(this);
    }

    _retryTimer?.cancel();
    _refreshTimer?.cancel();

    await _connectivitySubscription?.cancel();

    await _syncedController.close();

    debugPrint('[AUTOSYNC] Serviço encerrado.');
  }
}
