import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/journey.dart';
import '../providers/journey_providers.dart';

class FinishJourneyPage extends ConsumerStatefulWidget {
  final Journey journey;

  const FinishJourneyPage({super.key, required this.journey});

  @override
  ConsumerState<FinishJourneyPage> createState() => _FinishJourneyPageState();
}

class _FinishJourneyPageState extends ConsumerState<FinishJourneyPage> {
  final _formKey = GlobalKey<FormState>();

  final _kmController = TextEditingController();

  bool _finishing = false;

  @override
  void initState() {
    super.initState();

    if (widget.journey.kmRodados != null) {
      _kmController.text = widget.journey.kmRodados!
          .toStringAsFixed(2)
          .replaceAll('.', ',');
    }
  }

  @override
  void dispose() {
    _kmController.dispose();

    super.dispose();
  }

  double? _parseKm() {
    final text = _kmController.text.trim().replaceAll(',', '.');

    if (text.isEmpty) {
      return null;
    }

    return double.tryParse(text);
  }

  String _formatTime(DateTime date) {
    final local = date.toLocal();

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatDuration() {
    final duration = DateTime.now().difference(widget.journey.inicio);

    if (duration.isNegative) {
      return '0min';
    }

    final hours = duration.inHours;

    final minutes = duration.inMinutes.remainder(60);

    if (hours == 0) {
      return '${minutes}min';
    }

    return '${hours}h '
        '${minutes}min';
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final km = _parseKm();

    setState(() {
      _finishing = true;
    });

    final repository = ref.read(journeyRepositoryProvider);

    try {
      await repository.finish(widget.journey.idJornada);

      if (km != null) {
        try {
          if (widget.journey.kmRodados != null) {
            await repository.updateMileage(
              journeyId: widget.journey.idJornada,
              km: km,
            );
          } else {
            await repository.registerMileage(
              journeyId: widget.journey.idJornada,
              km: km,
            );
          }
        } catch (e) {
          if (!mounted) return;

          await showDialog<void>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                icon: const Icon(Icons.warning_amber_rounded),
                title: const Text('Jornada finalizada'),
                content: Text(
                  'A jornada foi finalizada, '
                  'mas a quilometragem não '
                  'pôde ser salva.\n\n'
                  '${e.toString().replaceFirst('Exception: ', '')}\n\n'
                  'Você poderá registrar o KM '
                  'posteriormente pelo histórico.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Entendi'),
                  ),
                ],
              );
            },
          );

          if (!mounted) return;

          Navigator.pop(context, true);

          return;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jornada finalizada com sucesso.')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _finishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar jornada')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Icon(
                        Icons.directions_car_filled_outlined,
                        size: 42,
                        color: theme.colorScheme.primary,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        widget.journey.veiculoNome,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: _JourneySummary(
                              label: 'Início',
                              value: _formatTime(widget.journey.inicio),
                            ),
                          ),

                          Expanded(
                            child: _JourneySummary(
                              label: 'Tempo',
                              value: _formatDuration(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Quilometragem',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 5),

              Text(
                'Informe quantos quilômetros '
                'foram rodados durante esta '
                'jornada. Esse campo pode ser '
                'preenchido depois.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _kmController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'KM rodados (opcional)',
                  hintText: 'Ex.: 126,4',
                  prefixIcon: Icon(Icons.route_outlined),
                  suffixText: 'km',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();

                  if (text.isEmpty) {
                    return null;
                  }

                  final km = double.tryParse(text.replaceAll(',', '.'));

                  if (km == null) {
                    return 'Informe uma quilometragem válida.';
                  }

                  if (km <= 0) {
                    return 'A quilometragem deve ser maior que zero.';
                  }

                  if (km > 999999.99) {
                    return 'Quilometragem acima do limite permitido.';
                  }

                  final decimal = RegExp(r'^\d+([,.]\d{1,2})?$');

                  if (!decimal.hasMatch(text)) {
                    return 'Use no máximo 2 casas decimais.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 30),

              FilledButton.icon(
                onPressed: _finishing ? null : _finish,
                icon: _finishing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.stop_circle_outlined),
                label: Text(
                  _finishing ? 'Finalizando...' : 'Finalizar jornada',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneySummary extends StatelessWidget {
  final String label;
  final String value;

  const _JourneySummary({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
