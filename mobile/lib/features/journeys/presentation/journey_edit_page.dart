import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/journey.dart';
import '../data/journey_repository.dart';
import '../providers/journey_providers.dart';

class JourneyEditPage extends ConsumerStatefulWidget {
  final Journey journey;

  const JourneyEditPage({super.key, required this.journey});

  @override
  ConsumerState<JourneyEditPage> createState() => _JourneyEditPageState();
}

class _JourneyEditPageState extends ConsumerState<JourneyEditPage> {
  final _kmController = TextEditingController();

  List<JourneyVehicleOption> _vehicles = [];

  late String _idVeiculo;
  late DateTime _inicio;
  DateTime? _fim;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _idVeiculo = widget.journey.idVeiculo;

    _inicio = widget.journey.inicio;

    _fim = widget.journey.fim;

    if (widget.journey.kmRodados != null) {
      _kmController.text = widget.journey.kmRodados!.toStringAsFixed(2);
    }

    Future.microtask(_load);
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final vehicles = await ref.read(journeyRepositoryProvider).loadVehicles();

    if (!mounted) {
      return;
    }

    setState(() {
      _vehicles = vehicles;
      _loading = false;
    });
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
          .update(
            idJornada: widget.journey.idJornada,
            idVeiculo: _idVeiculo,
            inicio: _inicio,
            fim: _fim,
            kmRodados: km,
          );

      if (!mounted) {
        return;
      }

      if (result.pending) {
        _message('Alteração salva no aparelho. Sincronização pendente.');
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
      appBar: AppBar(title: const Text('Editar jornada')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                          if (value != null) {
                            setState(() {
                              _idVeiculo = value;
                            });
                          }
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
                    ),
                    child: Text(_formatDateTime(_inicio)),
                  ),
                ),

                const SizedBox(height: 16),

                if (_fim != null)
                  InkWell(
                    onTap: _saving
                        ? null
                        : () async {
                            final value = await _pickDateTime(_fim!);

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
                      ),
                      child: Text(_formatDateTime(_fim!)),
                    ),
                  ),

                if (_fim != null) const SizedBox(height: 16),

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
                  label: Text(_saving ? 'Salvando...' : 'Salvar alterações'),
                ),
              ],
            ),
    );
  }
}
