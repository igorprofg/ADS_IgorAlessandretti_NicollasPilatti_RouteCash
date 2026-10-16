import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vehicles/data/vehicle.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/create_expense_request.dart';
import '../data/expense.dart';
import '../data/expense_category.dart';
import '../data/update_expense_request.dart';
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

  List<Vehicle> _vehicles = [];
  List<ExpenseCategory> _categories = [];

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

      _data = widget.expense!.data;
    }

    Future.microtask(_carregarDados);
  }

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    try {
      final vehicleRepository = ref.read(vehicleRepositoryProvider);

      final categoryRepository = ref.read(expenseCategoryRepositoryProvider);

      final resultados = await Future.wait([
        vehicleRepository.findAll(),
        categoryRepository.findAll(),
      ]);

      final vehicles = resultados[0] as List<Vehicle>;

      final categories = resultados[1] as List<ExpenseCategory>;

      if (!mounted) return;

      setState(() {
        _vehicles = vehicles;
        _categories = categories;

        _idVeiculo ??= vehicles.isNotEmpty ? vehicles.first.idVeiculo : null;

        _idCategoria ??= categories.isNotEmpty
            ? categories.first.idCategoria
            : null;

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

  Future<void> _criarCategoria() async {
    final controller = TextEditingController();

    final nome = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nova categoria'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome da categoria',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final nome = controller.text.trim();

                if (nome.isEmpty) {
                  return;
                }

                Navigator.pop(context, nome);
              },
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (nome == null || nome.trim().isEmpty) {
      return;
    }

    try {
      final repository = ref.read(expenseCategoryRepositoryProvider);

      final categoria = await repository.create(nome.trim());

      if (!mounted) return;

      setState(() {
        _categories = [..._categories, categoria];

        _categories.sort(
          (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
        );

        _idCategoria = categoria.idCategoria;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoria criada com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre um veículo antes de registrar uma despesa.'),
        ),
      );

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

    setState(() {
      _salvando = true;
    });

    try {
      final repository = ref.read(expenseRepositoryProvider);

      if (_editando) {
        await repository.update(
          widget.expense!.idDespesa,
          UpdateExpenseRequest(
            idVeiculo: _idVeiculo,
            idCategoria: _idCategoria,
            valor: valor,
            data: _data,
          ),
        );
      } else {
        await repository.create(
          CreateExpenseRequest(
            idVeiculo: _idVeiculo!,
            idCategoria: _idCategoria!,
            valor: valor,
            data: _data,
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
        title: Text(_editando ? 'Editar despesa' : 'Nova despesa'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? Center(child: Text(_erro!))
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
                          child: Text(
                            '${vehicle.marca} '
                            '${vehicle.modelo}',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
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

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
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
                            onChanged: (value) {
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
                        ),

                        const SizedBox(width: 8),

                        IconButton.filled(
                          onPressed: _criarCategoria,
                          tooltip: 'Nova categoria',
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _valorController,
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
                          (value ?? '').replaceAll(',', '.'),
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
                      onTap: _selecionarData,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_month),
                        ),
                        child: Text(_formatarData(_data)),
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
                              _editando
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
}
