import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/platform_icon.dart';

import '../../platforms/data/platform.dart';
import '../../platforms/providers/platform_providers.dart';
import '../../vehicles/data/vehicle.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/create_earning_request.dart';
import '../data/earning.dart';
import '../data/update_earning_request.dart';
import '../providers/earning_providers.dart';

class EarningFormPage extends ConsumerStatefulWidget {
  final Earning? earning;

  const EarningFormPage({super.key, this.earning});

  @override
  ConsumerState<EarningFormPage> createState() => _EarningFormPageState();
}

class _EarningFormPageState extends ConsumerState<EarningFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();

  List<Vehicle> _vehicles = [];
  List<Platform> _platforms = [];

  String? _idVeiculo;
  String? _idPlataforma;

  DateTime _data = DateTime.now();

  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  bool get _editando => widget.earning != null;

  bool _possuiLogoPadrao(String nome) {
    final normalizado = nome.trim().toLowerCase();

    return normalizado == 'uber' ||
        normalizado == '99' ||
        normalizado == 'indrive' ||
        normalizado == 'in drive';
  }

  @override
  void initState() {
    super.initState();

    if (widget.earning != null) {
      _idVeiculo = widget.earning!.idVeiculo;
      _idPlataforma = widget.earning!.idPlataforma;
      _valorController.text = widget.earning!.valor.toStringAsFixed(2);
      _data = widget.earning!.data;
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

      final platformRepository = ref.read(platformRepositoryProvider);

      final resultados = await Future.wait([
        vehicleRepository.findAll(),
        platformRepository.findAll(),
      ]);

      final vehicles = resultados[0] as List<Vehicle>;
      final todasPlataformas = resultados[1] as List<Platform>;

      final platforms = todasPlataformas
          .where((platform) => platform.ativa)
          .toList();

      if (!mounted) return;

      setState(() {
        _vehicles = vehicles;
        _platforms = platforms;

        _idVeiculo ??= vehicles.isNotEmpty ? vehicles.first.idVeiculo : null;

        _idPlataforma ??= platforms.isNotEmpty
            ? platforms.first.idPlataforma
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

  Future<void> _selecionarData() async {
    final selecionada = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selecionada == null) return;

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
          content: Text('Cadastre um veículo antes de registrar um ganho.'),
        ),
      );
      return;
    }

    if (_idPlataforma == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não existe plataforma ativa disponível.'),
        ),
      );
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
      final repository = ref.read(earningRepositoryProvider);

      if (_editando) {
        await repository.update(
          widget.earning!.idGanho,
          UpdateEarningRequest(
            idVeiculo: _idVeiculo,
            idPlataforma: _idPlataforma,
            valor: valor,
            data: _data,
          ),
        );
      } else {
        await repository.create(
          CreateEarningRequest(
            idVeiculo: _idVeiculo!,
            idPlataforma: _idPlataforma!,
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
      appBar: AppBar(title: Text(_editando ? 'Editar ganho' : 'Novo ganho')),
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
                        return DropdownMenuItem(
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

                    DropdownButtonFormField<String>(
                      initialValue: _idPlataforma,
                      decoration: const InputDecoration(
                        labelText: 'Plataforma',
                        border: OutlineInputBorder(),
                      ),
                      selectedItemBuilder: (context) {
                        return _platforms.map((platform) {
                          final possuiLogo = _possuiLogoPadrao(platform.nome);

                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PlatformIcon(
                                  platformName: platform.nome,
                                  size: 36,
                                ),
                                if (!possuiLogo) ...[
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      platform.nome,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList();
                      },
                      items: _platforms.map((platform) {
                        return DropdownMenuItem<String>(
                          value: platform.idPlataforma,
                          child: Row(
                            children: [
                              PlatformIcon(
                                platformName: platform.nome,
                                size: 34,
                              ),
                              const SizedBox(width: 12),
                              Text(platform.nome),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _idPlataforma = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Selecione uma plataforma.';
                        }

                        return null;
                      },
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
                                  : 'Registrar ganho',
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
