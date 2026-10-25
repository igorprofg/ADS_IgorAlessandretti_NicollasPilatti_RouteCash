import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vehicle.dart';
import '../providers/vehicle_providers.dart';

class InactiveVehicleListPage extends ConsumerStatefulWidget {
  const InactiveVehicleListPage({super.key});

  @override
  ConsumerState<InactiveVehicleListPage> createState() =>
      _InactiveVehicleListPageState();
}

class _InactiveVehicleListPageState
    extends ConsumerState<InactiveVehicleListPage> {
  List<Vehicle> _vehicles = [];

  bool _carregando = true;
  bool _houveAlteracao = false;

  String? _erro;

  @override
  void initState() {
    super.initState();

    Future.microtask(_carregar);
  }

  Future<void> _carregar() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final repository = ref.read(vehicleRepositoryProvider);

      final vehicles = await repository.findInactive();

      if (!mounted) return;

      setState(() {
        _vehicles = vehicles;
        _carregando = false;
        _erro = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');

        _carregando = false;
      });
    }
  }

  Future<void> _reativar(Vehicle vehicle) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.restore, size: 38),
          title: const Text('Reativar veículo'),
          content: Text(
            'Deseja reativar '
            '${vehicle.marca} '
            '${vehicle.modelo}'
            '${vehicle.placa != null ? ' (${vehicle.placa})' : ''}?\n\n'
            'O veículo voltará a ficar disponível para novos lançamentos.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.restore),
              label: const Text('Reativar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      final repository = ref.read(vehicleRepositoryProvider);

      await repository.reactivate(vehicle.idVeiculo);

      if (!mounted) return;

      _houveAlteracao = true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veículo reativado com sucesso.')),
      );

      await _carregar();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _voltar() {
    Navigator.pop(context, _houveAlteracao);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _voltar();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Veículos inativos'),
          leading: IconButton(
            onPressed: _voltar,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro != null
            ? _buildErro()
            : _vehicles.isEmpty
            ? _buildVazio()
            : RefreshIndicator(
                onRefresh: _carregar,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vehicles.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final vehicle = _vehicles[index];

                    return _InactiveVehicleCard(
                      vehicle: vehicle,
                      onReactivate: () => _reativar(vehicle),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 58,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum veículo inativo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              'Os veículos removidos aparecerão aqui e poderão ser reativados.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52),
            const SizedBox(height: 16),
            Text(_erro!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InactiveVehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onReactivate;

  const _InactiveVehicleCard({
    required this.vehicle,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.directions_car_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${vehicle.marca} '
                        '${vehicle.modelo}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${vehicle.ano}'
                        '${vehicle.placa != null ? ' • ${vehicle.placa}' : ''}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Inativo',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onReactivate,
                icon: const Icon(Icons.restore),
                label: const Text('Reativar veículo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
