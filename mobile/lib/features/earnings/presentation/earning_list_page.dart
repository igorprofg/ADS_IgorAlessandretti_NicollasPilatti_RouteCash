import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/earning.dart';
import '../providers/earning_providers.dart';
import 'earning_form_page.dart';

class EarningListPage extends ConsumerStatefulWidget {
  const EarningListPage({super.key});

  @override
  ConsumerState<EarningListPage> createState() => _EarningListPageState();
}

class _EarningListPageState extends ConsumerState<EarningListPage> {
  List<Earning> _earnings = [];

  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();

    Future.microtask(_carregar);
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final repository = ref.read(earningRepositoryProvider);

      final earnings = await repository.findAll();

      if (!mounted) return;

      setState(() {
        _earnings = earnings;
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

  Future<void> _novo() async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const EarningFormPage()),
    );

    if (atualizado == true) {
      await _carregar();
    }
  }

  Future<void> _editar(Earning earning) async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EarningFormPage(earning: earning),
      ),
    );

    if (atualizado == true) {
      await _carregar();
    }
  }

  Future<void> _duplicar(Earning earning) async {
    final opcao = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Duplicar ganho'),
          content: const Text(
            'Deseja manter a data original ou escolher uma nova data?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, 'original');
              },
              child: const Text('Manter data'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, 'alterar');
              },
              child: const Text('Alterar data'),
            ),
          ],
        );
      },
    );

    if (opcao == null) {
      return;
    }

    DateTime? novaData;

    if (opcao == 'alterar') {
      novaData = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

      if (novaData == null) {
        return;
      }
    }

    try {
      final repository = ref.read(earningRepositoryProvider);

      await repository.duplicate(earning.idGanho, data: novaData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ganho duplicado com sucesso.')),
      );

      await _carregar();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _remover(Earning earning) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir ganho'),
          content: Text(
            'Deseja excluir o ganho de '
            'R\$ ${earning.valor.toStringAsFixed(2)}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      final repository = ref.read(earningRepositoryProvider);

      final mensagem = await repository.delete(earning.idGanho);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));

      await _carregar();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');

    final mes = data.month.toString().padLeft(2, '0');

    return '$dia/$mes/${data.year}';
  }

  String _formatarValor(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganhos')),
      floatingActionButton: FloatingActionButton(
        onPressed: _novo,
        tooltip: 'Registrar ganho',
        child: const Icon(Icons.add),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_erro!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _carregar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : _earnings.isEmpty
          ? const Center(child: Text('Nenhum ganho registrado.'))
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _earnings.length,
                itemBuilder: (context, index) {
                  final earning = _earnings[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.attach_money),
                      ),
                      title: Text(
                        'R\$ ${_formatarValor(earning.valor)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${earning.plataformaNome ?? 'Plataforma'}\n'
                          '${earning.veiculoMarca ?? ''} '
                          '${earning.veiculoModelo ?? ''}\n'
                          '${_formatarData(earning.data)}',
                        ),
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'editar') {
                            _editar(earning);
                          }

                          if (value == 'duplicar') {
                            _duplicar(earning);
                          }

                          if (value == 'excluir') {
                            _remover(earning);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'editar',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 12),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'duplicar',
                            child: Row(
                              children: [
                                Icon(Icons.content_copy),
                                SizedBox(width: 12),
                                Text('Duplicar'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'excluir',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline),
                                SizedBox(width: 12),
                                Text('Excluir'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
