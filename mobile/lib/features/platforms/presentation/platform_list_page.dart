import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform.dart';
import '../providers/platform_providers.dart';
import 'platform_form_page.dart';

class PlatformListPage extends ConsumerStatefulWidget {
  const PlatformListPage({super.key});

  @override
  ConsumerState<PlatformListPage> createState() => _PlatformListPageState();
}

class _PlatformListPageState extends ConsumerState<PlatformListPage> {
  List<Platform> _platforms = [];

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
      final repository = ref.read(platformRepositoryProvider);

      final platforms = await repository.findAll();

      if (!mounted) return;

      setState(() {
        _platforms = platforms;
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

  Future<void> _novaPlataforma() async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const PlatformFormPage()),
    );

    if (atualizado == true) {
      await _carregar();
    }
  }

  Future<void> _editar(Platform platform) async {
    if (platform.padrao) {
      return;
    }

    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PlatformFormPage(platform: platform),
      ),
    );

    if (atualizado == true) {
      await _carregar();
    }
  }

  Future<void> _alternarAtiva(Platform platform) async {
    try {
      final repository = ref.read(platformRepositoryProvider);

      await repository.toggleActive(platform.idPlataforma);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            platform.ativa ? 'Plataforma inativada.' : 'Plataforma ativada.',
          ),
        ),
      );

      await _carregar();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Plataformas')),

      floatingActionButton: FloatingActionButton(
        onPressed: _novaPlataforma,
        tooltip: 'Nova plataforma',
        child: const Icon(Icons.add),
      ),

      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? Center(child: Text(_erro!))
          : _platforms.isEmpty
          ? const Center(child: Text('Nenhuma plataforma cadastrada.'))
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _platforms.length,
                itemBuilder: (context, index) {
                  final platform = _platforms[index];

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        platform.ativa
                            ? Icons.check_circle
                            : Icons.pause_circle_outline,
                      ),
                      title: Text(platform.nome),
                      subtitle: Text(
                        platform.padrao
                            ? 'Plataforma padrão'
                            : 'Plataforma personalizada',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'editar') {
                            _editar(platform);
                          }

                          if (value == 'alternar') {
                            _alternarAtiva(platform);
                          }
                        },
                        itemBuilder: (context) => [
                          if (!platform.padrao)
                            const PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),

                          PopupMenuItem(
                            value: 'alternar',
                            child: Text(platform.ativa ? 'Inativar' : 'Ativar'),
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
