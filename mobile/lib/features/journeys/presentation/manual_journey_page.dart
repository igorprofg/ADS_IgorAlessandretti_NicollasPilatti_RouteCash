import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/journey_repository.dart';
import '../providers/journey_providers.dart';

class ManualJourneyPage extends ConsumerStatefulWidget {
  const ManualJourneyPage({super.key});

  @override
  ConsumerState<ManualJourneyPage> createState() => _ManualJourneyPageState();
}

class _ManualJourneyPageState extends ConsumerState<ManualJourneyPage> {
  final _kmController = TextEditingController();

  List<JourneyVehicleOption> _vehicles = [];

  String? _idVeiculo;

  late DateTime _inicio;
  late DateTime _fim;

  bool _loading = true;
  bool _saving = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _fim = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    _inicio = _fim.subtract(const Duration(hours: 1));

    Future.microtask(_load);
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final vehicles = await ref.read(journeyRepositoryProvider).loadVehicles();

      if (!mounted) {
        return;
      }

      JourneyVehicleOption? principal;

      for (final vehicle in vehicles) {
        if (vehicle.principal) {
          principal = vehicle;
          break;
        }
      }

      setState(() {
        _vehicles = vehicles;
        _idVeiculo =
            principal?.idVeiculo ??
            (vehicles.isNotEmpty ? vehicles.first.idVeiculo : null);

        _loading = false;

        if (vehicles.isEmpty) {
          _error = 'Não há veículo disponível no cache local.';
        }
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

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date == null || !mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (_idVeiculo == null) {
      return;
    }

    final kmText = _kmController.text.trim().replaceAll(',', '.');

    final km = kmText.isEmpty ? null : double.tryParse(kmText);

    if (kmText.isNotEmpty && km == null) {
      _message('Informe uma quilometragem válida.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final result = await ref
          .read(journeyRepositoryProvider)
          .saveManual(
            idVeiculo: _idVeiculo!,
            inicio: _inicio,
            fim: _fim,
            kmRodados: km,
          );

      if (!mounted) {
        return;
      }

      if (result.pending) {
        _message('Jornada salva no aparelho. Sincronização pendente.');
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
      appBar: AppBar(title: const Text('Registrar jornada manual')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _idVeiculo,
                  decoration: const InputDecoration(
                    labelText: 'Veículo',
                    border: OutlineInputBorder(),
                  ),
                  items: _vehicles.map((vehicle) {
                    return DropdownMenuItem<String>(
                      value: vehicle.idVeiculo,
                      child: Text(vehicle.nome),
                    );
                  }).toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _idVeiculo = value;
                          });
                        },
                ),

                const SizedBox(height: 16),

                InkWell(
                  onTap: _saving
                      ? null
                      : () async {
                          final value = await _pickDateTime(_inicio);

                          if (value != null && mounted) {
                            setState(() {
                              _inicio = value;
                            });
                          }
                        },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Início',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.play_arrow_outlined),
                    ),
                    child: Text(_formatDateTime(_inicio)),
                  ),
                ),

                const SizedBox(height: 16),

                InkWell(
                  onTap: _saving
                      ? null
                      : () async {
                          final value = await _pickDateTime(_fim);

                          if (value != null && mounted) {
                            setState(() {
                              _fim = value;
                            });
                          }
                        },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fim',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.stop_outlined),
                    ),
                    child: Text(_formatDateTime(_fim)),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _kmController,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quilometragem rodada (opcional)',
                    suffixText: 'km',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Salvando...' : 'Salvar jornada'),
                ),
              ],
            ),
    );
  }
}
