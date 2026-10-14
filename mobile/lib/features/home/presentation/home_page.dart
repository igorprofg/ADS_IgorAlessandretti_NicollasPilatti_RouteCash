import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage.dart';
import '../../auth/presentation/login_page.dart';
import '../../users/presentation/profile_page.dart';
import '../../users/providers/user_providers.dart';
import '../../vehicles/presentation/vehicle_list_page.dart';
import '../../platforms/presentation/platform_list_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Map<String, dynamic>? _usuario;

  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();

    Future.microtask(_carregarPerfil);
  }

  Future<void> _carregarPerfil() async {
    try {
      final repository = ref.read(userRepositoryProvider);

      final usuario = await repository.getMyProfile();

      if (!mounted) return;

      setState(() {
        _usuario = usuario;
        _erro = null;
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

  Future<void> _abrirPerfil() async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );

    if (!mounted) return;

    if (atualizado == true) {
      await _carregarPerfil();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso.')),
      );
    }
  }

  Future<void> _abrirVeiculos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VehicleListPage()),
    );
  }

  Future<void> _sair() async {
    await SecureStorage.deleteToken();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Cash'),
        actions: [
          IconButton(
            onPressed: _abrirPerfil,
            icon: const Icon(Icons.person),
            tooltip: 'Meu Perfil',
          ),
          IconButton(
            onPressed: _sair,
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro != null
            ? Center(child: Text(_erro!))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Olá, ${_usuario?['nome'] ?? ''}!',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(_usuario?['email'] ?? ''),

                  const SizedBox(height: 8),

                  Text('Tipo: ${_usuario?['tipo_usuario'] ?? ''}'),

                  const SizedBox(height: 32),

                  const Text('Usuário autenticado com sucesso.'),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _abrirVeiculos,
                      icon: const Icon(Icons.directions_car),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Meus Veículos'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PlatformListPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.apps),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Minhas Plataformas'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
