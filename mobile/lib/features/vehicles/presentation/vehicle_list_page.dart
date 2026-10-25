import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vehicle.dart';
import '../providers/vehicle_providers.dart';

import 'inactive_vehicle_list_page.dart';
import 'vehicle_form_page.dart';

class VehicleListPage extends ConsumerStatefulWidget {
  const VehicleListPage({super.key});

  @override
  ConsumerState<VehicleListPage> createState() => _VehicleListPageState();
}

class _VehicleListPageState extends ConsumerState<VehicleListPage> {
  List<Vehicle> _vehicles = [];

  bool _carregando = true;
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

      final vehicles = await repository.findAll();

      if (!mounted) return;

      setState(() {
        _vehicles = vehicles;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');

        _carregando = false;
      });
    }
  }

  Future<void> _novoVeiculo() async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const VehicleFormPage()),
    );

    if (atualizado == true) {
      await _carregar();
    }
  }

  Future<void> _editar(Vehicle vehicle) async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleFormPage(vehicle: vehicle),
      ),
    );

    if (atualizado == true) {
      await _carregar();
    }
  }

  Future<void> _abrirInativos() async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const InactiveVehicleListPage()),
    );

    if (alterou == true) {
      await _carregar();
    }
  }

  Future<void> _definirPrincipal(Vehicle vehicle) async {
    try {
      final repository = ref.read(vehicleRepositoryProvider);

      final mensagem = await repository.setPrincipal(vehicle.idVeiculo);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));

      await _carregar();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _remover(Vehicle vehicle) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.delete_outline, size: 36),
          title: const Text('Remover veículo'),
          content: Text(
            'Deseja remover '
            '${vehicle.marca} '
            '${vehicle.modelo}?\n\n'
            'O histórico financeiro será preservado.',
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
              child: const Text('Remover'),
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

      final mensagem = await repository.delete(vehicle.idVeiculo);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));

      await _carregar();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus veículos'),
        actions: [
          IconButton(
            onPressed: _abrirInativos,
            icon: const Icon(Icons.history),
            tooltip: 'Veículos inativos',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoVeiculo,
        icon: const Icon(Icons.add),
        label: const Text('Novo veículo'),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _vehicles.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildVehicleCard(_vehicles[index]);
                },
              ),
            ),
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: vehicle.principal
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                vehicle.principal
                    ? Icons.directions_car_filled
                    : Icons.directions_car_outlined,
                color: vehicle.principal
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${vehicle.marca} '
                          '${vehicle.modelo}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      if (vehicle.principal)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Principal',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _VehicleInfo(
                        icon: Icons.calendar_today_outlined,
                        text: vehicle.ano.toString(),
                      ),
                      _VehicleInfo(
                        icon: Icons.local_gas_station_outlined,
                        text: vehicle.combustivel,
                      ),
                      _VehicleInfo(
                        icon: Icons.speed_outlined,
                        text: '${vehicle.consumoMedio} km/l',
                      ),
                    ],
                  ),

                  if (vehicle.placa != null && vehicle.placa!.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.pin_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          vehicle.placa!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'editar':
                    _editar(vehicle);
                    break;

                  case 'principal':
                    _definirPrincipal(vehicle);
                    break;

                  case 'remover':
                    _remover(vehicle);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 12),
                      Text('Editar'),
                    ],
                  ),
                ),

                if (!vehicle.principal)
                  const PopupMenuItem(
                    value: 'principal',
                    child: Row(
                      children: [
                        Icon(Icons.star_outline),
                        SizedBox(width: 12),
                        Text('Definir como principal'),
                      ],
                    ),
                  ),

                const PopupMenuDivider(),

                const PopupMenuItem(
                  value: 'remover',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 12),
                      Text('Remover'),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
            const Icon(Icons.directions_car_outlined, size: 58),
            const SizedBox(height: 16),
            const Text(
              'Nenhum veículo cadastrado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              'Cadastre o veículo que você utiliza para começar seus lançamentos.',
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

class _VehicleInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _VehicleInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
