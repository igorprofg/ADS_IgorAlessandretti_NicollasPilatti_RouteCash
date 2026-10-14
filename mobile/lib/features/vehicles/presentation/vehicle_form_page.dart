import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/create_vehicle_request.dart';
import '../data/update_vehicle_request.dart';
import '../data/vehicle.dart';
import '../providers/vehicle_providers.dart';

class VehicleFormPage extends ConsumerStatefulWidget {
  final Vehicle? vehicle;

  const VehicleFormPage({super.key, this.vehicle});

  @override
  ConsumerState<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends ConsumerState<VehicleFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anoController = TextEditingController();
  final _combustivelController = TextEditingController();
  final _consumoController = TextEditingController();
  final _placaController = TextEditingController();

  bool _salvando = false;

  bool get _editando => widget.vehicle != null;

  @override
  void initState() {
    super.initState();

    final vehicle = widget.vehicle;

    if (vehicle != null) {
      _marcaController.text = vehicle.marca;
      _modeloController.text = vehicle.modelo;
      _anoController.text = vehicle.ano.toString();
      _combustivelController.text = vehicle.combustivel;
      _consumoController.text = vehicle.consumoMedio.toString();
      _placaController.text = vehicle.placa ?? '';
    }
  }

  @override
  void dispose() {
    _marcaController.dispose();
    _modeloController.dispose();
    _anoController.dispose();
    _combustivelController.dispose();
    _consumoController.dispose();
    _placaController.dispose();

    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      final repository = ref.read(vehicleRepositoryProvider);

      final ano = int.parse(_anoController.text.trim());

      final consumo = double.parse(
        _consumoController.text.trim().replaceAll(',', '.'),
      );

      if (_editando) {
        await repository.update(
          widget.vehicle!.idVeiculo,
          UpdateVehicleRequest(
            marca: _marcaController.text.trim(),
            modelo: _modeloController.text.trim(),
            ano: ano,
            combustivel: _combustivelController.text.trim(),
            consumoMedio: consumo,
            placa: _placaController.text.trim(),
          ),
        );
      } else {
        await repository.create(
          CreateVehicleRequest(
            marca: _marcaController.text.trim(),
            modelo: _modeloController.text.trim(),
            ano: ano,
            combustivel: _combustivelController.text.trim(),
            consumoMedio: consumo,
            placa: _placaController.text.trim(),
          ),
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar veículo' : 'Novo veículo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _marcaController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe a marca.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _modeloController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o modelo.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _anoController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Ano',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final ano = int.tryParse(value?.trim() ?? '');

                  if (ano == null) {
                    return 'Informe um ano válido.';
                  }

                  if (ano < 1950) {
                    return 'Ano inválido.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _combustivelController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Combustível',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o combustível.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _consumoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Consumo médio (km/l)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final consumo = double.tryParse(
                    (value ?? '').replaceAll(',', '.'),
                  );

                  if (consumo == null) {
                    return 'Informe um consumo válido.';
                  }

                  if (consumo < 0.1) {
                    return 'O consumo deve ser maior que zero.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _placaController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Placa (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              FilledButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _editando ? 'Salvar alterações' : 'Cadastrar veículo',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
