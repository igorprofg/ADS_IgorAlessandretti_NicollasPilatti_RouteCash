import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/platform_icon.dart';

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

  Set<String> _pendingIds = {};

  Map<String, String> _attentionReasons = {};

  bool _carregando = true;

  String? _erro;

  @override
  void initState() {
    super.initState();

    Future.microtask(_carregar);
  }

  Future<void> _carregar() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final repository = ref.read(platformRepositoryProvider);

      final platforms = await repository.findAll();

      final pendingIds = await repository.pendingIds();

      final attentionReasons = await repository.attentionReasons();

      if (!mounted) {
        return;
      }

      setState(() {
        _platforms = platforms;

        _pendingIds = pendingIds;

        _attentionReasons = attentionReasons;

        _carregando = false;
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

  Future<void> _sincronizarECarregar() async {
    final repository = ref.read(platformRepositoryProvider);

    await repository.trySync();

    await _carregar();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plataformas padrão não podem ter o nome alterado.'),
        ),
      );

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
    final acao = platform.ativa ? 'inativar' : 'ativar';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(
            platform.ativa
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 36,
          ),
          title: Text(
            platform.ativa ? 'Inativar plataforma' : 'Ativar plataforma',
          ),
          content: Text(
            'Deseja $acao '
            '"${platform.nome}"?',
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
              child: Text(platform.ativa ? 'Inativar' : 'Ativar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      final repository = ref.read(platformRepositoryProvider);

      await repository.toggleActive(platform.idPlataforma);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            platform.ativa ? 'Plataforma inativada.' : 'Plataforma ativada.',
          ),
        ),
      );

      await _carregar();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas plataformas'),
        actions: [
          IconButton(
            onPressed: _sincronizarECarregar,
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novaPlataforma,
        icon: const Icon(Icons.add),
        label: const Text('Nova plataforma'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? _buildErro()
          : _platforms.isEmpty
          ? _buildVazio()
          : RefreshIndicator(
              onRefresh: _sincronizarECarregar,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _platforms.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildPlatformCard(_platforms[index]);
                },
              ),
            ),
    );
  }

  Widget _buildPlatformCard(Platform platform) {
    final theme = Theme.of(context);

    final attentionReason = _attentionReasons[platform.idPlataforma];

    final pending = _pendingIds.contains(platform.idPlataforma);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: platform.ativa ? 1 : 0.45,
              child: PlatformIcon(platformName: platform.nome, size: 46),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          platform.nome,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      if (platform.padrao)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Padrão',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Row(
                    children: [
                      Icon(
                        platform.ativa
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        size: 16,
                        color: platform.ativa
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        platform.ativa ? 'Ativa' : 'Inativa',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  Text(
                    platform.padrao
                        ? 'Plataforma padrão do sistema'
                        : 'Plataforma personalizada',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  if (attentionReason != null) ...[
                    const SizedBox(height: 10),
                    _PlatformSyncStatus(
                      icon: Icons.warning_amber_rounded,
                      text: 'Precisa de atenção: $attentionReason',
                      error: true,
                    ),
                  ] else if (pending) ...[
                    const SizedBox(height: 10),
                    const _PlatformSyncStatus(
                      icon: Icons.cloud_upload_outlined,
                      text: 'Sincronização pendente',
                    ),
                  ],
                ],
              ),
            ),

            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'editar':
                    _editar(platform);
                    break;

                  case 'alternar':
                    _alternarAtiva(platform);
                    break;
                }
              },
              itemBuilder: (context) => [
                if (!platform.padrao)
                  const PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 12),
                        Text('Editar'),
                      ],
                    ),
                  ),

                PopupMenuItem(
                  value: 'alternar',
                  child: Row(
                    children: [
                      Icon(
                        platform.ativa
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      const SizedBox(width: 12),
                      Text(platform.ativa ? 'Inativar' : 'Ativar'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVazio() {
    return RefreshIndicator(
      onRefresh: _sincronizarECarregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone_android_outlined, size: 58),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhuma plataforma cadastrada',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Cadastre ou sincronize as plataformas utilizadas nos seus ganhos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
            const Icon(Icons.error_outline, size: 52),
            const SizedBox(height: 16),
            Text(_erro!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformSyncStatus extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool error;

  const _PlatformSyncStatus({
    required this.icon,
    required this.text,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final foreground = error
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    final background = error
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: foreground),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: error
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
