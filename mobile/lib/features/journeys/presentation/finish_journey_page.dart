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
  final _kmController = TextEditingController();

  DateTime _fim = DateTime.now();

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    if (widget.journey.kmRodados != null) {
      _kmController.text = widget.journey.kmRodados!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  Future<void> _selectEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fim,
      firstDate: widget.journey.inicio,
      lastDate: DateTime.now(),
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fim),
    );

    if (time == null) {
      return;
    }

    setState(() {
      _fim = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
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
          .finish(journey: widget.journey, fim: _fim, kmRodados: km);

      if (!mounted) {
        return;
      }

      if (result.pending) {
        _message('Jornada finalizada no aparelho. Sincronização pendente.');
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
      appBar: AppBar(title: const Text('Finalizar jornada')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Início', style: Theme.of(context).textTheme.labelLarge),

          const SizedBox(height: 6),

          Text(_formatDateTime(widget.journey.inicio)),

          const SizedBox(height: 20),

          InkWell(
            onTap: _saving ? null : _selectEnd,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Horário final',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
              child: Text(_formatDateTime(_fim)),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _kmController,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quilometragem rodada (opcional)',
              suffixText: 'km',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.flag_outlined),
            label: Text(_saving ? 'Finalizando...' : 'Finalizar jornada'),
          ),
        ],
      ),
    );
  }
}
