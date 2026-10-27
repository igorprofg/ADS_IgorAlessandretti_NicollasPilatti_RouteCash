import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_providers.dart';

class SyncDebugPage extends ConsumerStatefulWidget {
  const SyncDebugPage({super.key});

  @override
  ConsumerState<SyncDebugPage> createState() => _SyncDebugPageState();
}

class _SyncDebugPageState extends ConsumerState<SyncDebugPage> {
  final List<String> _logs = [];

  bool _running = false;

  void _log(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _logs.add(message);
    });
  }

  Future<void> _runSyncTest() async {
    if (_running) {
      return;
    }

    setState(() {
      _running = true;
      _logs.clear();
    });

    try {
      _log('Iniciando sincronização completa...');

      final manager = ref.read(syncManagerProvider);

      await manager.syncNow();

      _log('Envio de pendências concluído.');

      _log('Download e reconciliação concluídos.');

      final local = ref.read(syncLocalRepositoryProvider);

      final counts = await local.localCounts();

      _log('SQLite após reconciliação:');

      _log('Veículos: ${counts['veiculos']}');

      _log('Plataformas: ${counts['plataformas']}');

      _log('Categorias: ${counts['categorias']}');

      _log('Ganhos: ${counts['ganhos']}');

      _log('Despesas: ${counts['despesas']}');

      _log('Jornadas: ${counts['jornadas']}');

      _log('Outbox: ${counts['outbox']}');

      final attention = await local.findNeedsAttention();

      _log(
        'Precisam de atenção: '
        '${attention.length}',
      );

      _log('SINCRONIZAÇÃO COMPLETA COM SUCESSO.');
    } catch (e) {
      _log(
        'ERRO: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teste RF11')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _running ? null : _runSyncTest,
              icon: const Icon(Icons.sync),
              label: Text(
                _running ? 'Sincronizando...' : 'Testar sincronização completa',
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Card(
                child: _logs.isEmpty
                    ? const Center(child: Text('Toque no botão para testar.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _logs.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          return Text(_logs[index]);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
