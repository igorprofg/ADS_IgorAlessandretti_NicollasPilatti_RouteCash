import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/create_vehicle_request.dart';
import '../data/update_vehicle_request.dart';
import '../data/vehicle.dart';
import '../data/vehicle_repository.dart';
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

  String? _normalizarPlaca(String value) {
    final normalizada = value.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );

    if (normalizada.isEmpty) {
      return null;
    }

    return normalizada;
  }

  String? _validarPlaca(String? value) {
    final placa = _normalizarPlaca(value ?? '');

    if (placa == null) {
      return null;
    }

    if (placa.length != 7) {
      return 'A placa deve possuir 7 caracteres.';
    }

    final formatoBrasileiro = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$');

    if (!formatoBrasileiro.hasMatch(placa)) {
      return 'Informe uma placa válida.';
    }

    return null;
  }

  Future<bool> _confirmarReativacao(String mensagem) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.restore_outlined, size: 38),
          title: const Text('Veículo inativo encontrado'),
          content: Text(
            '$mensagem\n\n'
            'Deseja reativar esse veículo agora?',
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

    return confirmar == true;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _salvando = true;
    });

    try {
      final repository = ref.read(vehicleRepositoryProvider);

      final ano = int.parse(_anoController.text.trim());

      final consumo = double.parse(
        _consumoController.text.trim().replaceAll(',', '.'),
      );

      final placa = _normalizarPlaca(_placaController.text);

      if (_editando) {
        await repository.update(
          widget.vehicle!.idVeiculo,
          UpdateVehicleRequest(
            marca: _marcaController.text.trim(),
            modelo: _modeloController.text.trim(),
            ano: ano,
            combustivel: _combustivelController.text.trim(),
            consumoMedio: consumo,
            placa: placa,
          ),
        );

        if (!mounted) return;

        Navigator.pop(context, true);

        return;
      }

      try {
        await repository.create(
          CreateVehicleRequest(
            marca: _marcaController.text.trim(),
            modelo: _modeloController.text.trim(),
            ano: ano,
            combustivel: _combustivelController.text.trim(),
            consumoMedio: consumo,
            placa: placa,
          ),
        );

        if (!mounted) return;

        Navigator.pop(context, true);
      } on InactiveVehicleConflict catch (e) {
        if (!mounted) return;

        setState(() {
          _salvando = false;
        });

        final reativar = await _confirmarReativacao(e.message);

        if (!reativar || !mounted) {
          return;
        }

        setState(() {
          _salvando = true;
        });

        await repository.reactivate(e.vehicleId);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veículo reativado com sucesso.')),
        );

        Navigator.pop(context, true);
      }
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
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editando
                    ? 'Atualize os dados do veículo.'
                    : 'Cadastre o veículo utilizado nas suas atividades.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 22),

              TextFormField(
                controller: _marcaController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  prefixIcon: Icon(Icons.directions_car_outlined),
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
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  prefixIcon: Icon(Icons.car_rental_outlined),
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  labelText: 'Ano',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
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
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Combustível',
                  prefixIcon: Icon(Icons.local_gas_station_outlined),
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
                  labelText: 'Consumo médio',
                  suffixText: 'km/l',
                  prefixIcon: Icon(Icons.speed_outlined),
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
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                  LengthLimitingTextInputFormatter(8),
                  _UpperCaseTextFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Placa (opcional)',
                  hintText: 'ABC1D23',
                  prefixIcon: Icon(Icons.pin_outlined),
                  helperText: 'Formato antigo ou Mercosul',
                ),
                validator: _validarPlaca,
                onFieldSubmitted: (_) {
                  if (!_salvando) {
                    _salvar();
                  }
                },
              ),

              const SizedBox(height: 28),

              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _editando
                            ? Icons.save_outlined
                            : Icons.add_circle_outline,
                      ),
                label: Text(
                  _salvando
                      ? 'Salvando...'
                      : _editando
                      ? 'Salvar alterações'
                      : 'Cadastrar veículo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
