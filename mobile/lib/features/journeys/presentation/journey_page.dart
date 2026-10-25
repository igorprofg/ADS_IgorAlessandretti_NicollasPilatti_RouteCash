import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vehicles/data/vehicle.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/journey.dart';
import '../data/start_journey_request.dart';
import '../providers/journey_providers.dart';
import 'finish_journey_page.dart';
import 'journey_edit_page.dart';

class JourneyPage extends ConsumerStatefulWidget {
  const JourneyPage({super.key});

  @override
  ConsumerState<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends ConsumerState<JourneyPage> {
  List<Vehicle> _vehicles = [];
  List<Journey> _journeys = [];

  Journey? _journeyInProgress;

  String? _selectedVehicleId;

  bool _loading = true;
  bool _starting = false;

  String? _error;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final vehicleRepository = ref.read(vehicleRepositoryProvider);

      final journeyRepository = ref.read(journeyRepositoryProvider);

      final results = await Future.wait<Object?>([
        vehicleRepository.findAll(),
        journeyRepository.findAll(),
        journeyRepository.findInProgress(),
      ]);

      final vehicles = results[0] as List<Vehicle>;
      final journeys = results[1] as List<Journey>;
      final currentJourney = results[2] as Journey?;

      if (!mounted) return;

      setState(() {
        _vehicles = vehicles;
        _journeys = journeys;
        _journeyInProgress = currentJourney;

        if (_selectedVehicleId == null ||
            !vehicles.any(
              (vehicle) => vehicle.idVeiculo == _selectedVehicleId,
            )) {
          Vehicle? principal;

          for (final vehicle in vehicles) {
            if (vehicle.principal) {
              principal = vehicle;
              break;
            }
          }

          _selectedVehicleId =
              principal?.idVeiculo ??
              (vehicles.isNotEmpty ? vehicles.first.idVeiculo : null);
        }

        _loading = false;
      });

      _configureTimer();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');

        _loading = false;
      });
    }
  }

  void _configureTimer() {
    _timer?.cancel();

    if (_journeyInProgress == null) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _startJourney() async {
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione um veículo.')));

      return;
    }

    setState(() {
      _starting = true;
    });

    try {
      final repository = ref.read(journeyRepositoryProvider);

      await repository.start(
        StartJourneyRequest(idVeiculo: _selectedVehicleId!),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jornada iniciada com sucesso.')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  Future<void> _finishJourney() async {
    final journey = _journeyInProgress;

    if (journey == null) {
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FinishJourneyPage(journey: journey),
      ),
    );

    if (updated == true) {
      await _loadData();
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
      await _loadData();
    }
  }

  Duration _currentDuration() {
    final journey = _journeyInProgress;

    if (journey == null) {
      return Duration.zero;
    }

    final now = DateTime.now();

    final difference = now.difference(journey.inicio);

    if (difference.isNegative) {
      return Duration.zero;
    }

    return difference;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;

    final minutes = duration.inMinutes.remainder(60);

    final seconds = duration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _formatMinutes(int? minutes) {
    if (minutes == null) {
      return '--';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '${remainingMinutes}min';
    }

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}min';
  }

  String _formatTime(DateTime date) {
    final local = date.toLocal();

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    return '$day/$month/${local.year}';
  }

  String _formatKm(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jornadas'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_journeyInProgress != null)
                      _buildCurrentJourney()
                    else
                      _buildStartJourney(),

                    const SizedBox(height: 28),

                    const Text(
                      'Histórico',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildHistory(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStartJourney() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: theme.colorScheme.primary,
                    size: 30,
                  ),
                ),

                const SizedBox(width: 14),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Iniciar jornada',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text('Comece a registrar seu tempo de trabalho.'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            if (_vehicles.isEmpty) ...[
              const Text(
                'Você precisa cadastrar um veículo ativo antes de iniciar uma jornada.',
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedVehicleId,
                decoration: const InputDecoration(
                  labelText: 'Veículo',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
                items: _vehicles.map((vehicle) {
                  final plate =
                      vehicle.placa != null && vehicle.placa!.isNotEmpty
                      ? ' • ${vehicle.placa}'
                      : '';

                  return DropdownMenuItem<String>(
                    value: vehicle.idVeiculo,
                    child: Text(
                      '${vehicle.marca} '
                      '${vehicle.modelo}'
                      '$plate',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _starting
                    ? null
                    : (value) {
                        setState(() {
                          _selectedVehicleId = value;
                        });
                      },
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _starting ? null : _startJourney,
                  icon: _starting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(_starting ? 'Iniciando...' : 'Iniciar jornada'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentJourney() {
    final journey = _journeyInProgress!;

    final theme = Theme.of(context);

    final duration = _currentDuration();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),

                const SizedBox(width: 8),

                const Expanded(
                  child: Text(
                    'Jornada em andamento',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            Icon(
              Icons.directions_car_filled_outlined,
              size: 42,
              color: theme.colorScheme.primary,
            ),

            const SizedBox(height: 8),

            Text(
              journey.veiculoNome,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),

            if (journey.veiculoPlaca != null &&
                journey.veiculoPlaca!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                journey.veiculoPlaca!,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],

            const SizedBox(height: 20),

            Text(
              _formatDuration(duration),
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              'Iniciada às '
              '${_formatTime(journey.inicio)}',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _finishJourney,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Finalizar jornada'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    final finished = _journeys.where((journey) => journey.fim != null).toList();

    if (finished.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 46,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nenhuma jornada finalizada',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  'Suas jornadas concluídas aparecerão aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: finished.map((journey) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildHistoryCard(journey),
        );
      }).toList(),
    );
  }

  Widget _buildHistoryCard(Journey journey) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.directions_car_outlined),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        journey.veiculoNome,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(journey.inicio),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                PopupMenuButton<String>(
                  tooltip: 'Opções',
                  onSelected: (value) {
                    if (value == 'editar') {
                      _editJourney(journey);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 10),
                          Text('Editar jornada'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _HistoryInfo(
                    icon: Icons.schedule_outlined,
                    label: 'Horário',
                    value:
                        '${_formatTime(journey.inicio)}'
                        ' → '
                        '${_formatTime(journey.fim!)}',
                  ),
                ),

                Expanded(
                  child: _HistoryInfo(
                    icon: Icons.timer_outlined,
                    label: 'Duração',
                    value: _formatMinutes(journey.duracaoMinutos),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            _HistoryInfo(
              icon: Icons.route_outlined,
              label: 'Quilometragem',
              value: journey.kmRodados != null
                  ? '${_formatKm(journey.kmRodados!)} km'
                  : 'Não informada',
            ),
          ],
        ),
      ),
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
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HistoryInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),

        const SizedBox(width: 7),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
