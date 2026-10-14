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
    setState(() {
      _carregando = true;
      _erro = null;
    });

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
          title: const Text('Remover veículo'),
          content: Text(
            'Deseja remover ${vehicle.marca} '
            '${vehicle.modelo}?',
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
        title: const Text('Meus Veículos'),
        actions: [
          IconButton(
            onPressed: _abrirInativos,
            icon: const Icon(Icons.history),
            tooltip: 'Veículos inativos',
          ),
        ],
      ),

      // Botão "+" para cadastrar veículo
      floatingActionButton: FloatingActionButton(
        onPressed: _novoVeiculo,
        tooltip: 'Cadastrar veículo',
        child: const Icon(Icons.add),
      ),

      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? Center(child: Text(_erro!))
          : _vehicles.isEmpty
          ? const Center(child: Text('Nenhum veículo cadastrado.'))
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = _vehicles[index];

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        vehicle.principal
                            ? Icons.directions_car_filled
                            : Icons.directions_car,
                      ),
                      title: Text(
                        '${vehicle.marca} '
                        '${vehicle.modelo}',
                      ),
                      subtitle: Text(
                        '${vehicle.ano} • '
                        '${vehicle.combustivel}\n'
                        '${vehicle.consumoMedio} km/l'
                        '${vehicle.placa != null ? ' • ${vehicle.placa}' : ''}'
                        '${vehicle.principal ? '\nVeículo principal' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'editar') {
                            _editar(vehicle);
                          }

                          if (value == 'principal') {
                            _definirPrincipal(vehicle);
                          }

                          if (value == 'remover') {
                            _remover(vehicle);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'editar',
                            child: Text('Editar'),
                          ),
                          if (!vehicle.principal)
                            const PopupMenuItem(
                              value: 'principal',
                              child: Text('Definir como principal'),
                            ),
                          const PopupMenuItem(
                            value: 'remover',
                            child: Text('Remover'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
