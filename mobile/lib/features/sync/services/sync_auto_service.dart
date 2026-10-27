import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

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

  final StreamController<void> _syncedController =
      StreamController<void>.broadcast();

  Stream<void> get onSynced => _syncedController.stream;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Timer? _retryTimer;
  Timer? _refreshTimer;

  bool _started = false;
  bool _syncing = false;

  void start() {
    if (_started) {
      return;
    }

    _started = true;

    WidgetsBinding.instance.addObserver(this);

    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final hasNetwork = !results.contains(ConnectivityResult.none);

      if (hasNetwork) {
        unawaited(tryNow(forceFullSync: true));
      }
    });

    // Se existem pendências, tenta novamente com frequência.
    // Isso também detecta quando o NestJS volta mesmo que
    // Wi-Fi/dados não tenham mudado.
    _retryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(tryNow());
    });

    // Atualiza o snapshot periodicamente mesmo sem pendências.
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(tryNow(forceFullSync: true));
    });

    unawaited(tryNow(forceFullSync: true));
  }

  Future<bool> tryNow({bool forceFullSync = false}) async {
    if (_syncing) {
      return false;
    }

    if (!forceFullSync) {
      final pending = await localRepository.findPending(limit: 1);

      if (pending.isEmpty) {
        return false;
      }
    }

    _syncing = true;

    try {
      await syncManager.syncNow();

      if (!_syncedController.isClosed) {
        _syncedController.add(null);
      }

      return true;
    } catch (_) {
      // O backend ainda pode estar indisponível.
      // A outbox permanece intacta e uma nova tentativa
      // será feita automaticamente.
      return false;
    } finally {
      _syncing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(tryNow(forceFullSync: true));
    }
  }

  Future<void> dispose() async {
    if (!_started) {
      return;
    }

    _started = false;

    WidgetsBinding.instance.removeObserver(this);

    _retryTimer?.cancel();
    _refreshTimer?.cancel();

    await _connectivitySubscription?.cancel();
    await _syncedController.close();
  }
}
