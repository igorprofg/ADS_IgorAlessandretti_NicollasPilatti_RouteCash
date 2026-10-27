import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/expense.dart';
import '../data/expense_repository.dart';
import '../providers/expense_providers.dart';

class ExpenseFormPage extends ConsumerStatefulWidget {
  final Expense? expense;

  const ExpenseFormPage({super.key, this.expense});

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _valorController = TextEditingController();

  final _observacaoController = TextEditingController();

  List<ExpenseVehicleOption> _vehicles = [];
  List<ExpenseCategoryOption> _categories = [];

  String? _idVeiculo;
  String? _idCategoria;

  DateTime _data = DateTime.now();

  bool _carregando = true;
  bool _salvando = false;

  String? _erro;

  bool get _editando => widget.expense != null;

  @override
  void initState() {
    super.initState();

    if (widget.expense != null) {
      _idVeiculo = widget.expense!.idVeiculo;

      _idCategoria = widget.expense!.idCategoria;

      _valorController.text = widget.expense!.valor.toStringAsFixed(2);

      _observacaoController.text = widget.expense!.observacao ?? '';

      _data = widget.expense!.data;
    }

    Future.microtask(_carregarDados);
  }

  @override
  void dispose() {
    _valorController.dispose();
    _observacaoController.dispose();

    super.dispose();
  }

  Future<void> _carregarDados() async {
    try {
      final repository = ref.read(expenseRepositoryProvider);

      final referenceData = await repository.loadReferenceData();

      if (!mounted) {
        return;
      }

      setState(() {
        _vehicles = referenceData.vehicles;

        _categories = referenceData.categories;

        if (_idVeiculo == null) {
          ExpenseVehicleOption? principal;

          for (final vehicle in _vehicles) {
            if (vehicle.principal) {
              principal = vehicle;
              break;
            }
          }

          _idVeiculo =
              principal?.idVeiculo ??
              (_vehicles.isNotEmpty ? _vehicles.first.idVeiculo : null);
        }

        _idCategoria ??= _categories.isNotEmpty
            ? _categories.first.idCategoria
            : null;

        _carregando = false;

        if (_vehicles.isEmpty || _categories.isEmpty) {
          _erro =
              'Não há veículos e categorias disponíveis no cache local. '
              'Conecte-se à internet e sincronize o aplicativo ao menos uma vez.';
        } else {
          _erro = null;
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');

        _carregando = false;
      });
    }
  }

  Future<void> _selecionarData() async {
    final selecionada = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selecionada == null) {
      return;
    }

    setState(() {
      _data = selecionada;
    });
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');

    final mes = data.month.toString().padLeft(2, '0');

    return '$dia/$mes/${data.year}';
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_idVeiculo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione um veículo.')));

      return;
    }

    if (_idCategoria == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione uma categoria.')));

      return;
    }

    final valor = double.tryParse(
      _valorController.text.trim().replaceAll(',', '.'),
    );

    if (valor == null || valor <= 0) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _salvando = true;
    });

    try {
      final repository = ref.read(expenseRepositoryProvider);

      final idDespesa = _editando
          ? widget.expense!.idDespesa
          : const Uuid().v4();

      final pending = await repository.save(
        idDespesa: idDespesa,
        idVeiculo: _idVeiculo!,
        idCategoria: _idCategoria!,
        valor: valor,
        data: _data,
        observacao: _observacaoController.text,
      );

      if (!mounted) {
        return;
      }

      if (pending) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Despesa salva no aparelho. Sincronização pendente.'),
          ),
        );
      }

      Navigator.pop(context, true);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar despesa' : 'Nova despesa'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? _buildErro()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      onChanged: _salvando
                          ? null
                          : (value) {
                              setState(() {
                                _idVeiculo = value;
                              });
                            },
                      validator: (value) {
                        if (value == null) {
                          return 'Selecione um veículo.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _idCategoria,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.idCategoria,
                          child: Text(category.nome),
                        );
                      }).toList(),
                      onChanged: _salvando
                          ? null
                          : (value) {
                              setState(() {
                                _idCategoria = value;
                              });
                            },
                      validator: (value) {
                        if (value == null) {
                          return 'Selecione uma categoria.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'As categorias disponíveis offline são as da última sincronização.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _valorController,
                      enabled: !_salvando,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final numero = double.tryParse(
                          (value ?? '').trim().replaceAll(',', '.'),
                        );

                        if (numero == null) {
                          return 'Informe um valor válido.';
                        }

                        if (numero <= 0) {
                          return 'O valor deve ser maior que zero.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    InkWell(
                      onTap: _salvando ? null : _selecionarData,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_formatarData(_data)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _observacaoController,
                      enabled: !_salvando,
                      maxLength: 255,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Observação (opcional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    FilledButton.icon(
                      onPressed: _salvando ? null : _salvar,
                      icon: _salvando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _salvando
                            ? 'Salvando...'
                            : _editando
                            ? 'Salvar alterações'
                            : 'Registrar despesa',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52),

            const SizedBox(height: 16),

            Text(_erro!, textAlign: TextAlign.center),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _carregarDados,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
