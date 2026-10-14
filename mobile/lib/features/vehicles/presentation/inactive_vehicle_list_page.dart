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
          title: const Text('Reativar veículo'),
          content: Text(
            'Deseja reativar ${vehicle.marca} '
            '${vehicle.modelo}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reativar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      final repository = ref.read(vehicleRepositoryProvider);

      final mensagem = await repository.reactivate(vehicle.idVeiculo);

      if (!mounted) return;

      _houveAlteracao = true;

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _houveAlteracao);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Veículos inativos')),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro != null
            ? Center(child: Text(_erro!))
            : _vehicles.isEmpty
            ? const Center(child: Text('Nenhum veículo inativo.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = _vehicles[index];

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.directions_car),
                      title: Text(
                        '${vehicle.marca} '
                        '${vehicle.modelo}',
                      ),
                      subtitle: Text(
                        '${vehicle.ano}'
                        '${vehicle.placa != null ? ' • ${vehicle.placa}' : ''}',
                      ),
                      trailing: IconButton(
                        onPressed: () => _reativar(vehicle),
                        icon: const Icon(Icons.restore),
                        tooltip: 'Reativar',
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
