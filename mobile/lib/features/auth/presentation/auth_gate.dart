import 'package:flutter/material.dart';

import '../../../core/storage/secure_storage.dart';
import '../../home/presentation/home_page.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _carregando = true;
  bool _autenticado = false;

  @override
  void initState() {
    super.initState();
    _verificarSessao();
  }

  Future<void> _verificarSessao() async {
    final token = await SecureStorage.getToken();

    if (!mounted) return;

    setState(() {
      _autenticado = token != null && token.isNotEmpty;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_autenticado) {
      return const HomePage();
    }

    return const LoginPage();
  }
}
