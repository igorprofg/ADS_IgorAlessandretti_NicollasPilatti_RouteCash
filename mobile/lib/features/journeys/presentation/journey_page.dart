import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/journey.dart';
import '../data/journey_repository.dart';
import '../providers/journey_providers.dart';
import 'finish_journey_page.dart';
import 'journey_edit_page.dart';
import 'manual_journey_page.dart';

class JourneyPage extends ConsumerStatefulWidget {
  const JourneyPage({super.key});

  @override
  ConsumerState<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends ConsumerState<JourneyPage> {
  List<Journey> _journeys = [];
  Set<String> _pendingIds = {};

  Journey? _inProgress;

  bool _loading = true;
  String? _error;

  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _inProgress != null) {
        setState(() {});
      }
    });

    Future.microtask(() => _load(synchronize: true));
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool synchronize = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final repository = ref.read(journeyRepositoryProvider);

      if (synchronize) {
        await repository.trySync();
      }

      final results = await Future.wait([
        repository.findAll(),
        repository.findInProgress(),
        repository.pendingIds(),
      ]);

      final journeys = results[0] as List<Journey>;

      final inProgress = results[1] as Journey?;

      final pendingIds = results[2] as Set<String>;

      if (!mounted) {
        return;
      }

      setState(() {
        _journeys = journeys;
        _inProgress = inProgress;
        _pendingIds = pendingIds;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _startJourney() async {
    final repository = ref.read(journeyRepositoryProvider);

    try {
      final vehicles = await repository.loadVehicles();

      if (!mounted) {
        return;
      }

      if (vehicles.isEmpty) {
        _message('Nenhum veículo ativo disponível.');
        return;
      }

      final selected = await showModalBottomSheet<JourneyVehicleOption>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Selecionar veículo',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),

                for (final vehicle in vehicles)
                  ListTile(
                    leading: Icon(
                      vehicle.principal
                          ? Icons.directions_car_filled
                          : Icons.directions_car_outlined,
                    ),
                    title: Text(vehicle.nome),
                    subtitle: vehicle.principal
                        ? const Text('Veículo principal')
                        : null,
                    onTap: () {
                      Navigator.pop(context, vehicle);
                    },
                  ),

                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );

      if (selected == null) {
        return;
      }

      final result = await repository.start(idVeiculo: selected.idVeiculo);

      if (!mounted) {
        return;
      }

      if (result.pending) {
        _message('Jornada iniciada no aparelho. Sincronização pendente.');
      }

      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }

      _message(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _finishJourney() async {
    final journey = _inProgress;

    if (journey == null) {
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FinishJourneyPage(journey: journey),
      ),
    );

    if (updated == true && mounted) {
      await _load();
    }
  }

  Future<void> _manualJourney() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const ManualJourneyPage()),
    );

    if (updated == true && mounted) {
      await _load();
    }
  }

  Future<void> _editJourney(Journey journey) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => JourneyEditPage(journey: journey),
      ),
    );

    if (updated == true && mounted) {
      await _load();
    }
  }

  Future<void> _deleteJourney(Journey journey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir jornada?'),
        content: const Text(
          'A jornada será removida dos indicadores e do histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final pending = await ref
          .read(journeyRepositoryProvider)
          .delete(journey.idJornada);

      if (!mounted) {
        return;
      }

      if (pending) {
        _message(
          'Jornada removida do aparelho. Exclusão pendente de sincronização.',
        );
      }

      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }

      _message(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _durationText(Journey journey) {
    final duration = journey.duracao;

    final hours = duration.inHours;

    final minutes = duration.inMinutes.remainder(60);

    final seconds = duration.inSeconds.remainder(60);

    if (journey.emAndamento) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${hours}h ${minutes}min';
  }

  String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');

    final m = value.month.toString().padLeft(2, '0');

    final h = value.hour.toString().padLeft(2, '0');

    final min = value.minute.toString().padLeft(2, '0');

    return '$d/$m/${value.year} $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jornadas'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(synchronize: true),
            tooltip: 'Sincronizar',
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: _inProgress == null
          ? FloatingActionButton.extended(
              onPressed: _startJourney,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar jornada'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: () => _load(synchronize: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  if (_inProgress != null) _buildInProgress(_inProgress!),

                  if (_inProgress != null) const SizedBox(height: 16),

                  OutlinedButton.icon(
                    onPressed: _manualJourney,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Registrar jornada manualmente'),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Histórico',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 10),

                  if (_journeys.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhuma jornada registrada.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  for (final journey in _journeys)
                    if (!journey.emAndamento) _buildHistoryCard(journey),
                ],
              ),
            ),
    );
  }

  Widget _buildInProgress(Journey journey) {
    final pending = _pendingIds.contains(journey.idJornada);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined),

                const SizedBox(width: 8),

                const Expanded(
                  child: Text(
                    'Jornada em andamento',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),

                if (pending) const Chip(label: Text('Pendente')),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              _durationText(journey),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 8),

            Text(
              '${journey.veiculoNome} • '
              '${_formatDateTime(journey.inicio)}',
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _finishJourney,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Finalizar jornada'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Journey journey) {
    final pending = _pendingIds.contains(journey.idJornada);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: const CircleAvatar(child: Icon(Icons.route_outlined)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                journey.veiculoNome,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (pending)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Chip(label: Text('Pendente')),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${_formatDateTime(journey.inicio)}\n'
            '${_durationText(journey)}'
            '${journey.kmRodados == null ? '' : ' • ${journey.kmRodados!.toStringAsFixed(2)} km'}',
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _editJourney(journey);
            } else if (value == 'delete') {
              _deleteJourney(journey);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _load(synchronize: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
