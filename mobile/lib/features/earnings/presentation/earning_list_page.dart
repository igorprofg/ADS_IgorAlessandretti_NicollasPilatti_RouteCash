import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/platform_icon.dart';
import '../../sync/providers/sync_providers.dart';
import '../data/earning.dart';
import '../providers/earning_providers.dart';
import 'earning_form_page.dart';

class EarningListPage extends ConsumerStatefulWidget {
  const EarningListPage({super.key});

  @override
  ConsumerState<EarningListPage> createState() => _EarningListPageState();
}

class _EarningListPageState extends ConsumerState<EarningListPage> {
  List<Earning> _earnings = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    Future.microtask(_loadEarnings);
  }

  Future<void> _loadEarnings() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final repository = ref.read(earningRepositoryProvider);

      final earnings = await repository.findAll();

      if (!mounted) {
        return;
      }

      setState(() {
        _earnings = earnings;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');

        _loading = false;
      });
    }
  }

  Future<void> _createEarning() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const EarningFormPage()),
    );

    if (!mounted) {
      return;
    }

    if (updated == true) {
      await _loadEarnings();
    }
  }

  Future<void> _editEarning(Earning earning) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EarningFormPage(earning: earning),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updated == true) {
      await _loadEarnings();
    }
  }

  Future<void> _duplicateEarning(Earning earning) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EarningFormPage(earning: earning, duplicando: true),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updated == true) {
      await _loadEarnings();
    }
  }

  Future<void> _deleteEarning(Earning earning) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.delete_outline),
          title: const Text('Excluir ganho?'),
          content: Text(
            'O ganho de ${_formatCurrency(earning.valor)} '
            'de ${_formatDate(earning.data)} será excluído.\n\n'
            'Ele deixará de participar dos indicadores financeiros.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final repository = ref.read(syncRepositoryProvider);

      final result = await repository.excluir(
        entidade: 'ganho',
        id: earning.idGanho,
      );

      if (!mounted) {
        return;
      }

      if (!result.sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.motivo ?? 'Não foi possível excluir o ganho.'),
          ),
        );

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ganho excluído com sucesso.')),
      );

      await _loadEarnings();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(2).split('.');

    final integer = parts[0];
    final decimal = parts[1];

    final buffer = StringBuffer();

    for (var i = 0; i < integer.length; i++) {
      final remaining = integer.length - i;

      buffer.write(integer[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'R\$ ${buffer.toString()},$decimal';
  }

  String _vehicleName(Earning earning) {
    final value =
        '${earning.veiculoMarca ?? ''} '
                '${earning.veiculoModelo ?? ''}'
            .trim();

    return value.isEmpty ? 'Veículo' : value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganhos'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadEarnings,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createEarning,
        icon: const Icon(Icons.add),
        label: const Text('Novo ganho'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadEarnings,
              child: _earnings.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _earnings.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _buildCard(_earnings[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildCard(Earning earning) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PlatformIcon(
                  platformName: earning.plataformaNome ?? 'Ganho',
                  size: 42,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        earning.plataformaNome ?? 'Ganho',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        '${_vehicleName(earning)} • '
                        '${_formatDate(earning.data)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                PopupMenuButton<String>(
                  tooltip: 'Opções',
                  onSelected: (value) {
                    switch (value) {
                      case 'editar':
                        _editEarning(earning);
                        break;

                      case 'duplicar':
                        _duplicateEarning(earning);
                        break;

                      case 'excluir':
                        _deleteEarning(earning);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 10),
                          Text('Editar ganho'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'duplicar',
                      child: Row(
                        children: [
                          Icon(Icons.copy_outlined),
                          SizedBox(width: 10),
                          Text('Duplicar ganho'),
                        ],
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'excluir',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 10),
                          Text(
                            'Excluir ganho',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              _formatCurrency(earning.valor),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),

            if (earning.observacao != null &&
                earning.observacao!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        earning.observacao!.trim(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 100),

        Icon(
          Icons.account_balance_wallet_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),

        const SizedBox(height: 16),

        const Text(
          'Nenhum ganho registrado',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 6),

        Text(
          'Seus ganhos aparecerão aqui.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52),

            const SizedBox(height: 16),

            Text(_error!, textAlign: TextAlign.center),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _loadEarnings,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
