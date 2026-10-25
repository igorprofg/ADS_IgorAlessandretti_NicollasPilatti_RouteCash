import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/journey.dart';
import '../data/update_journey_request.dart';
import '../providers/journey_providers.dart';

class JourneyEditPage extends ConsumerStatefulWidget {
  final Journey journey;

  const JourneyEditPage({super.key, required this.journey});

  @override
  ConsumerState<JourneyEditPage> createState() => _JourneyEditPageState();
}

class _JourneyEditPageState extends ConsumerState<JourneyEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _kmController = TextEditingController();

  late DateTime _inicio;
  DateTime? _fim;

  bool _salvando = false;
  bool _removendoKm = false;

  @override
  void initState() {
    super.initState();

    _inicio = widget.journey.inicio.toLocal();
    _fim = widget.journey.fim?.toLocal();

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

  Future<DateTime?> _selecionarDataHora(
    DateTime atual, {
    required String titulo,
  }) async {
    final data = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: titulo,
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
    );

    if (data == null) {
      return null;
    }

    if (!mounted) return null;

    final horario = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(atual),
      helpText: titulo,
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
    );

    if (horario == null) {
      return null;
    }

    return DateTime(
      data.year,
      data.month,
      data.day,
      horario.hour,
      horario.minute,
    );
  }

  Future<void> _editarInicio() async {
    final selecionado = await _selecionarDataHora(
      _inicio,
      titulo: 'Horário de início',
    );

    if (selecionado == null || !mounted) {
      return;
    }

    setState(() {
      _inicio = selecionado;
    });
  }

  Future<void> _editarFim() async {
    final atual = _fim ?? DateTime.now();

    final selecionado = await _selecionarDataHora(
      atual,
      titulo: 'Horário final',
    );

    if (selecionado == null || !mounted) {
      return;
    }

    setState(() {
      _fim = selecionado;
    });
  }

  double? _parseKm() {
    final texto = _kmController.text.trim();

    if (texto.isEmpty) {
      return null;
    }

    return double.tryParse(texto.replaceAll(',', '.'));
  }

  String _formatarDataHora(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');

    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');

    return '$dia/$mes/${data.year} às $hora:$minuto';
  }

  String _formatarDuracao() {
    final fim = _fim;

    if (fim == null) {
      return 'Em andamento';
    }

    final diferenca = fim.difference(_inicio);

    if (diferenca.isNegative || diferenca.inMinutes == 0) {
      return 'Período inválido';
    }

    final horas = diferenca.inMinutes ~/ 60;
    final minutos = diferenca.inMinutes % 60;

    if (horas == 0) {
      return '${minutos}min';
    }

    if (minutos == 0) {
      return '${horas}h';
    }

    return '${horas}h ${minutos}min';
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_fim != null && !_fim!.isAfter(_inicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O horário final deve ser posterior ao horário de início.',
          ),
        ),
      );

      return;
    }

    if (_inicio.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O horário de início não pode estar no futuro.'),
        ),
      );

      return;
    }

    if (_fim != null && _fim!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O horário final não pode estar no futuro.'),
        ),
      );

      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _salvando = true;
    });

    final repository = ref.read(journeyRepositoryProvider);

    try {
      await repository.update(
        widget.journey.idJornada,
        UpdateJourneyRequest(inicio: _inicio, fim: _fim),
      );

      final km = _parseKm();

      if (km != null) {
        if (widget.journey.kmRodados == null) {
          await repository.registerMileage(
            journeyId: widget.journey.idJornada,
            km: km,
          );
        } else {
          await repository.updateMileage(
            journeyId: widget.journey.idJornada,
            km: km,
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jornada atualizada com sucesso.')),
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
          _salvando = false;
        });
      }
    }
  }

  Future<void> _removerQuilometragem() async {
    if (widget.journey.kmRodados == null) {
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.delete_outline),
          title: const Text('Remover quilometragem?'),
          content: const Text(
            'A jornada será mantida. Apenas o registro de quilômetros '
            'rodados será removido.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) {
      return;
    }

    setState(() {
      _removendoKm = true;
    });

    try {
      final repository = ref.read(journeyRepositoryProvider);

      await repository.deleteMileage(widget.journey.idJornada);

      if (!mounted) return;

      _kmController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quilometragem removida com sucesso.')),
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
          _removendoKm = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar jornada')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.directions_car_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.journey.veiculoNome,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (widget.journey.veiculoPlaca != null &&
                                widget.journey.veiculoPlaca!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                widget.journey.veiculoPlaca!,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Horários',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 12),

              _DateTimeField(
                label: 'Início',
                value: _formatarDataHora(_inicio),
                icon: Icons.play_circle_outline,
                onTap: _salvando ? null : _editarInicio,
              ),

              const SizedBox(height: 12),

              _DateTimeField(
                label: 'Fim',
                value: _fim != null
                    ? _formatarDataHora(_fim!)
                    : 'Não finalizada',
                icon: Icons.stop_circle_outlined,
                onTap: _salvando ? null : _editarFim,
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Duração',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      _formatarDuracao(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Quilometragem',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 5),

              Text(
                widget.journey.kmRodados == null
                    ? 'Nenhuma quilometragem foi registrada nesta jornada.'
                    : 'Altere os quilômetros rodados ou remova o registro.',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _kmController,
                enabled: !_salvando && !_removendoKm,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'KM rodados',
                  hintText: 'Ex.: 126,4',
                  prefixIcon: Icon(Icons.route_outlined),
                  suffixText: 'km',
                ),
                validator: (value) {
                  final texto = (value ?? '').trim();

                  if (texto.isEmpty) {
                    return null;
                  }

                  final decimal = RegExp(r'^\d+([,.]\d{1,2})?$');

                  if (!decimal.hasMatch(texto)) {
                    return 'Use no máximo 2 casas decimais.';
                  }

                  final km = double.tryParse(texto.replaceAll(',', '.'));

                  if (km == null) {
                    return 'Informe uma quilometragem válida.';
                  }

                  if (km <= 0) {
                    return 'A quilometragem deve ser maior que zero.';
                  }

                  if (km > 999999.99) {
                    return 'Quilometragem acima do limite permitido.';
                  }

                  return null;
                },
              ),

              if (widget.journey.kmRodados != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _salvando || _removendoKm
                      ? null
                      : _removerQuilometragem,
                  icon: _removendoKm
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(
                    _removendoKm ? 'Removendo...' : 'Remover quilometragem',
                  ),
                ),
              ],

              const SizedBox(height: 30),

              FilledButton.icon(
                onPressed: _salvando || _removendoKm ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_salvando ? 'Salvando...' : 'Salvar alterações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _DateTimeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}
