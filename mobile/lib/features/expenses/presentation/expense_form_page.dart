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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _valorController = TextEditingController();

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
        _erro = null;
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
    final nome = await showDialog<String>(
      context: context,
      builder: (context) {
        return const _NewCategoryDialog();
      },
    );

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
      helpText: 'Selecionar data da despesa',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
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

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52),
            const SizedBox(height: 16),
            Text(
              _erro ?? 'Não foi possível carregar os dados.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _carregando = true;
                  _erro = null;
                });

                _carregarDados();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
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
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _editando
                          ? 'Atualize os dados da despesa.'
                          : 'Informe os dados da nova despesa.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 22),

                    DropdownButtonFormField<String>(
                      initialValue: _idVeiculo,
                      decoration: const InputDecoration(
                        labelText: 'Veículo',
                        prefixIcon: Icon(Icons.directions_car_outlined),
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
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem<String>(
                                value: category.idCategoria,
                                child: Text(
                                  category.nome,
                                  overflow: TextOverflow.ellipsis,
                                ),
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

                        SizedBox(
                          height: 56,
                          child: IconButton.filled(
                            onPressed: _criarCategoria,
                            tooltip: 'Nova categoria',
                            icon: const Icon(Icons.add),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Use o botão + para criar uma categoria personalizada.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextFormField(
                      controller: _valorController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        prefixIcon: Icon(Icons.payments_outlined),
                        prefixText: 'R\$ ',
                        hintText: '0,00',
                      ),
                      validator: (value) {
                        final texto = (value ?? '').trim().replaceAll(',', '.');

                        final numero = double.tryParse(texto);

                        if (texto.isEmpty) {
                          return 'Informe o valor da despesa.';
                        }

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
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                          suffixIcon: Icon(Icons.chevron_right),
                        ),
                        child: Text(
                          _formatarData(_data),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
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

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final TextEditingController _controller = TextEditingController();

  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _criar() {
    final nome = _controller.text.trim();

    if (nome.isEmpty) {
      setState(() {
        _erro = 'Informe o nome da categoria.';
      });

      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pop(nome);
  }

  void _cancelar() {
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova categoria'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Nome da categoria',
          hintText: 'Ex.: Lavagem',
          errorText: _erro,
        ),
        onChanged: (_) {
          if (_erro != null) {
            setState(() {
              _erro = null;
            });
          }
        },
        onSubmitted: (_) {
          _criar();
        },
      ),
      actions: [
        TextButton(onPressed: _cancelar, child: const Text('Cancelar')),
        FilledButton(onPressed: _criar, child: const Text('Criar')),
      ],
    );
  }
}
