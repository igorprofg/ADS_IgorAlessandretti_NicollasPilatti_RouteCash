import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/platform_icon.dart';

import '../data/earning.dart';
import '../data/earning_repository.dart';
import '../providers/earning_providers.dart';

class EarningFormPage extends ConsumerStatefulWidget {
  final Earning? earning;
  final bool duplicando;

  const EarningFormPage({
    super.key,
    this.earning,
    this.duplicando = false,
  });

  @override
  ConsumerState<EarningFormPage> createState() =>
      _EarningFormPageState();
}

class _EarningFormPageState
    extends ConsumerState<EarningFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _valorController =
      TextEditingController();

  final _observacaoController =
      TextEditingController();

  List<EarningVehicleOption> _vehicles = [];

  List<EarningPlatformOption> _platforms =
      [];

  String? _idVeiculo;
  String? _idPlataforma;

  DateTime _data = DateTime.now();

  bool _carregando = true;
  bool _salvando = false;

  String? _erro;

  bool get _editando =>
      widget.earning != null &&
      !widget.duplicando;

  bool get _duplicando =>
      widget.earning != null &&
      widget.duplicando;

  bool _possuiLogoPadrao(
    String nome,
  ) {
    final normalizado =
        nome.trim().toLowerCase();

    return normalizado == 'uber' ||
        normalizado == '99' ||
        normalizado == 'indrive' ||
        normalizado == 'in drive';
  }

  @override
  void initState() {
    super.initState();

    if (widget.earning != null) {
      _idVeiculo =
          widget.earning!.idVeiculo;

      _idPlataforma =
          widget.earning!.idPlataforma;

      _valorController.text =
          widget.earning!.valor
              .toStringAsFixed(2);

      _observacaoController.text =
          widget.earning!.observacao ?? '';

      _data = widget.duplicando
          ? DateTime.now()
          : widget.earning!.data;
    }

    Future.microtask(
      _carregarDados,
    );
  }

  @override
  void dispose() {
    _valorController.dispose();
    _observacaoController.dispose();

    super.dispose();
  }

  Future<void> _carregarDados() async {
    try {
      final repository = ref.read(
        earningRepositoryProvider,
      );

      final referenceData =
          await repository
              .loadReferenceData();

      final vehicles =
          referenceData.vehicles;

      final platforms =
          referenceData.platforms;

      if (!mounted) {
        return;
      }

      setState(() {
        _vehicles = vehicles;
        _platforms = platforms;

        if (_idVeiculo == null) {
          EarningVehicleOption?
              principal;

          for (final vehicle
              in vehicles) {
            if (vehicle.principal) {
              principal = vehicle;
              break;
            }
          }

          _idVeiculo =
              principal?.idVeiculo ??
              (vehicles.isNotEmpty
                  ? vehicles.first.idVeiculo
                  : null);
        }

        _idPlataforma ??=
            platforms.isNotEmpty
                ? platforms.first.idPlataforma
                : null;

        _carregando = false;

        if (vehicles.isEmpty ||
            platforms.isEmpty) {
          _erro =
              'Não há veículos e plataformas disponíveis no cache local. '
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
        _erro = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );

        _carregando = false;
      });
    }
  }

  Future<void> _selecionarData() async {
    final selecionada =
        await showDatePicker(
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

  String _formatarData(
    DateTime data,
  ) {
    final dia = data.day
        .toString()
        .padLeft(2, '0');

    final mes = data.month
        .toString()
        .padLeft(2, '0');

    return '$dia/$mes/${data.year}';
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_idVeiculo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione um veículo.',
          ),
        ),
      );

      return;
    }

    if (_idPlataforma == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione uma plataforma.',
          ),
        ),
      );

      return;
    }

    final valor = double.tryParse(
      _valorController.text
          .trim()
          .replaceAll(',', '.'),
    );

    if (valor == null ||
        valor <= 0) {
      return;
    }

    FocusManager.instance.primaryFocus
        ?.unfocus();

    setState(() {
      _salvando = true;
    });

    try {
      final repository = ref.read(
        earningRepositoryProvider,
      );

      final idGanho = _editando
          ? widget.earning!.idGanho
          : const Uuid().v4();

      final pending =
          await repository.save(
        idGanho: idGanho,
        idVeiculo: _idVeiculo!,
        idPlataforma:
            _idPlataforma!,
        valor: valor,
        data: _data,
        observacao:
            _observacaoController.text,
      );

      if (!mounted) {
        return;
      }

      if (pending) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Ganho salvo no aparelho. Sincronização pendente.',
            ),
          ),
        );
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e
                .toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editando
              ? 'Editar ganho'
              : _duplicando
                  ? 'Duplicar ganho'
                  : 'Novo ganho',
        ),
      ),
      body: _carregando
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _erro != null
              ? _buildErro()
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.all(
                    24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .stretch,
                      children: [
                        DropdownButtonFormField<
                            String>(
                          initialValue:
                              _idVeiculo,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Veículo',
                            border:
                                OutlineInputBorder(),
                          ),
                          items:
                              _vehicles.map(
                            (vehicle) {
                              return DropdownMenuItem<
                                  String>(
                                value: vehicle
                                    .idVeiculo,
                                child: Text(
                                  vehicle.nome,
                                ),
                              );
                            },
                          ).toList(),
                          onChanged: _salvando
                              ? null
                              : (value) {
                                  setState(
                                    () {
                                      _idVeiculo =
                                          value;
                                    },
                                  );
                                },
                          validator: (value) {
                            if (value == null) {
                              return 'Selecione um veículo.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        DropdownButtonFormField<
                            String>(
                          initialValue:
                              _idPlataforma,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Plataforma',
                            border:
                                OutlineInputBorder(),
                          ),
                          selectedItemBuilder:
                              (context) {
                            return _platforms
                                .map(
                              (platform) {
                                final possuiLogo =
                                    _possuiLogoPadrao(
                                  platform.nome,
                                );

                                return Align(
                                  alignment:
                                      Alignment
                                          .centerLeft,
                                  child: Row(
                                    mainAxisSize:
                                        MainAxisSize
                                            .min,
                                    children: [
                                      PlatformIcon(
                                        platformName:
                                            platform
                                                .nome,
                                        size: 36,
                                      ),
                                      if (!possuiLogo) ...[
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        Flexible(
                                          child:
                                              Text(
                                            platform
                                                .nome,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ).toList();
                          },
                          items:
                              _platforms.map(
                            (platform) {
                              return DropdownMenuItem<
                                  String>(
                                value: platform
                                    .idPlataforma,
                                child: Row(
                                  children: [
                                    PlatformIcon(
                                      platformName:
                                          platform.nome,
                                      size: 34,
                                    ),
                                    const SizedBox(
                                      width: 12,
                                    ),
                                    Text(
                                      platform.nome,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ).toList(),
                          onChanged: _salvando
                              ? null
                              : (value) {
                                  setState(
                                    () {
                                      _idPlataforma =
                                          value;
                                    },
                                  );
                                },
                          validator: (value) {
                            if (value == null) {
                              return 'Selecione uma plataforma.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        TextFormField(
                          controller:
                              _valorController,
                          enabled:
                              !_salvando,
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              const InputDecoration(
                            labelText: 'Valor',
                            prefixText: 'R\$ ',
                            border:
                                OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final numero =
                                double.tryParse(
                              (value ?? '')
                                  .trim()
                                  .replaceAll(
                                    ',',
                                    '.',
                                  ),
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

                        const SizedBox(
                          height: 16,
                        ),

                        InkWell(
                          onTap: _salvando
                              ? null
                              : _selecionarData,
                          child:
                              InputDecorator(
                            decoration:
                                const InputDecoration(
                              labelText: 'Data',
                              prefixIcon:
                                  Icon(
                                Icons
                                    .calendar_today_outlined,
                              ),
                              border:
                                  OutlineInputBorder(),
                            ),
                            child: Text(
                              _formatarData(
                                _data,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        TextFormField(
                          controller:
                              _observacaoController,
                          enabled:
                              !_salvando,
                          maxLength: 255,
                          maxLines: 3,
                          textCapitalization:
                              TextCapitalization
                                  .sentences,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Observação (opcional)',
                            prefixIcon:
                                Icon(
                              Icons
                                  .notes_outlined,
                            ),
                            alignLabelWithHint:
                                true,
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        FilledButton.icon(
                          onPressed:
                              _salvando
                                  ? null
                                  : _salvar,
                          icon: _salvando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .save_outlined,
                                ),
                          label: Text(
                            _salvando
                                ? 'Salvando...'
                                : _editando
                                    ? 'Salvar alterações'
                                    : _duplicando
                                        ? 'Salvar cópia'
                                        : 'Registrar ganho',
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
        padding:
            const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons
                  .cloud_off_outlined,
              size: 52,
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              _erro!,
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height: 20,
            ),

            FilledButton.icon(
              onPressed:
                  _carregarDados,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Tentar novamente',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
