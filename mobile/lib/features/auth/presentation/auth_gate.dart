import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/security/app_lock_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';

import '../../home/presentation/home_page.dart';

import 'app_lock_page.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _carregando = true;
  bool _autenticado = false;
  bool _bloqueado = false;

  @override
  void initState() {
    super.initState();

    _verificarSessao();
  }

  Future<void> _verificarSessao() async {
    try {
      final token = await SecureStorage.getToken();

      final userId = await SecureStorage.getUserId();

      final possuiToken = token != null && token.trim().isNotEmpty;

      final possuiUsuario = userId != null && userId.trim().isNotEmpty;

      if (!possuiToken || !possuiUsuario) {
        await SecureStorage.clearSession();

        if (!mounted) {
          return;
        }

        setState(() {
          _autenticado = false;
          _bloqueado = false;
          _carregando = false;
        });

        return;
      }

      await AppDatabase.instance.useUser(userId);

      final lockService = AppLockService();

      final bloqueioAtivo = await lockService.isLockEnabled();

      if (!mounted) {
        return;
      }

      setState(() {
        _autenticado = true;

        _bloqueado = bloqueioAtivo;

        _carregando = false;
      });
    } catch (_) {
      try {
        await AppDatabase.instance.releaseUser();
      } catch (_) {}

      await SecureStorage.clearSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _autenticado = false;
        _bloqueado = false;
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const _RouteCashSplash();
    }

    if (!_autenticado) {
      return const LoginPage();
    }

    if (_bloqueado) {
      return const AppLockPage();
    }

    return const HomePage();
  }
}

class _RouteCashSplash extends StatelessWidget {
  const _RouteCashSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryDark, AppTheme.primaryBright],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/route_cash_logo.png',
                    width: 290,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 38),

                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 17),

                  const Text(
                    'Preparando seus dados...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Seu controle financeiro na rota.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
