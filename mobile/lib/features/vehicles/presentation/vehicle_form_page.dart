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

      _consumoController.text = vehicle.consumoMedio
          .toStringAsFixed(2)
          .replaceAll('.', ',');

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
    final normalizada = value.trim().toUpperCase();

    if (normalizada.isEmpty) {
      return null;
    }

    return normalizada;
  }

  String? _validarMarca(String? value) {
    final texto = value?.trim() ?? '';

    if (texto.isEmpty) {
      return 'Informe a marca.';
    }

    if (texto.length > 50) {
      return 'A marca deve ter no máximo 50 caracteres.';
    }

    return null;
  }

  String? _validarModelo(String? value) {
    final texto = value?.trim() ?? '';

    if (texto.isEmpty) {
      return 'Informe o modelo.';
    }

    if (texto.length > 50) {
      return 'O modelo deve ter no máximo 50 caracteres.';
    }

    return null;
  }

  String? _validarAno(String? value) {
    final ano = int.tryParse(value?.trim() ?? '');

    if (ano == null) {
      return 'Informe um ano válido.';
    }

    if (ano < 1950 || ano > 2100) {
      return 'O ano deve estar entre 1950 e 2100.';
    }

    return null;
  }

  String? _validarCombustivel(String? value) {
    final texto = value?.trim() ?? '';

    if (texto.isEmpty) {
      return 'Informe o combustível.';
    }

    if (texto.length > 30) {
      return 'O combustível deve ter no máximo 30 caracteres.';
    }

    return null;
  }

  String? _validarConsumo(String? value) {
    final texto = (value ?? '').trim().replaceAll(',', '.');

    if (texto.isEmpty) {
      return 'Informe o consumo médio.';
    }

    final formato = RegExp(r'^\d+(\.\d{1,2})?$');

    if (!formato.hasMatch(texto)) {
      return 'Use um número com no máximo 2 casas decimais.';
    }

    final consumo = double.tryParse(texto);

    if (consumo == null) {
      return 'Informe um consumo válido.';
    }

    if (consumo <= 0) {
      return 'O consumo deve ser maior que zero.';
    }

    if (consumo > 999.99) {
      return 'O consumo deve ser no máximo 999,99.';
    }

    return null;
  }

  String? _validarPlaca(String? value) {
    final placa = _normalizarPlaca(value ?? '');

    if (placa == null) {
      return null;
    }

    if (placa.length > 10) {
      return 'A placa deve ter no máximo 10 caracteres.';
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

        if (!mounted) {
          return;
        }

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

        if (!mounted) {
          return;
        }

        Navigator.pop(context, true);
      } on InactiveVehicleConflict catch (e) {
        if (!mounted) {
          return;
        }

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

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veículo reativado com sucesso.')),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

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
    final theme = Theme.of(context);

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
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 22),

              TextFormField(
                controller: _marcaController,
                enabled: !_salvando,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _validarMarca,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _modeloController,
                enabled: !_salvando,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  prefixIcon: Icon(Icons.car_rental_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _validarModelo,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _anoController,
                enabled: !_salvando,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  labelText: 'Ano',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _validarAno,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _combustivelController,
                enabled: !_salvando,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                decoration: const InputDecoration(
                  labelText: 'Combustível',
                  prefixIcon: Icon(Icons.local_gas_station_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _validarCombustivel,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _consumoController,
                enabled: !_salvando,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Consumo médio',
                  suffixText: 'km/l',
                  prefixIcon: Icon(Icons.speed_outlined),
                  helperText: 'Máximo 999,99',
                  border: OutlineInputBorder(),
                ),
                validator: _validarConsumo,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _placaController,
                enabled: !_salvando,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  _UpperCaseTextFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Placa (opcional)',
                  hintText: 'ABC1D23',
                  prefixIcon: Icon(Icons.pin_outlined),
                  helperText: 'Até 10 caracteres',
                  border: OutlineInputBorder(),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
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

              const SizedBox(height: 12),

              Text(
                'As alterações são salvas no aparelho e '
                'sincronizadas automaticamente quando houver conexão.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
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
