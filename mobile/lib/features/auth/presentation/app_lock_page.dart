import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/security/app_lock_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';

import '../../home/presentation/home_page.dart';

import 'login_page.dart';

class AppLockPage extends StatefulWidget {
  const AppLockPage({super.key});

  @override
  State<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends State<AppLockPage> {
  final _pinController = TextEditingController();

  final _service = AppLockService();

  bool _biometriaAtivada = false;

  bool _biometriaDisponivel = false;

  bool _autenticando = false;

  bool _verificandoPin = false;

  bool _ocultarPin = true;

  String? _erro;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializar();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();

    super.dispose();
  }

  Future<void> _inicializar() async {
    try {
      final ativada = await _service.isBiometricEnabled();

      final disponivel = ativada ? await _service.canUseBiometrics() : false;

      if (!mounted) {
        return;
      }

      setState(() {
        _biometriaAtivada = ativada;

        _biometriaDisponivel = disponivel;
      });

      if (ativada && disponivel) {
        await Future.delayed(const Duration(milliseconds: 350));

        if (mounted) {
          await _autenticarBiometria();
        }
      }
    } catch (_) {}
  }

  Future<void> _autenticarBiometria() async {
    if (_autenticando) {
      return;
    }

    setState(() {
      _autenticando = true;
      _erro = null;
    });

    try {
      final ok = await _service.authenticateWithBiometrics();

      if (ok && mounted) {
        _desbloquear();
      }
    } finally {
      if (mounted) {
        setState(() {
          _autenticando = false;
        });
      }
    }
  }

  Future<void> _verificarPin() async {
    final pin = _pinController.text;

    if (pin.length < 4) {
      setState(() {
        _erro = 'Informe seu PIN.';
      });

      return;
    }

    setState(() {
      _verificandoPin = true;
      _erro = null;
    });

    try {
      final valido = await _service.verifyPin(pin);

      if (!mounted) {
        return;
      }

      if (valido) {
        _desbloquear();

        return;
      }

      _pinController.clear();

      setState(() {
        _erro = 'PIN incorreto.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _verificandoPin = false;
        });
      }
    }
  }

  void _desbloquear() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  Future<void> _sairDaConta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.logout),
          title: const Text('Sair da conta?'),
          content: const Text(
            'Você precisará de conexão com a internet para fazer login novamente.',
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
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    await AppDatabase.instance.releaseUser();

    await SecureStorage.clearSession();

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset(
                            'assets/images/route_cash_logo.png',
                            height: 74,
                            fit: BoxFit.contain,
                          ),

                          const SizedBox(height: 28),

                          Text(
                            'Route Cash bloqueado',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 7),

                          Text(
                            'Use seu PIN ou biometria para continuar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: 28),

                          TextField(
                            controller: _pinController,
                            obscureText: _ocultarPin,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: 'PIN',
                              counterText: '',
                              prefixIcon: const Icon(Icons.pin_outlined),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _ocultarPin = !_ocultarPin;
                                  });
                                },
                                icon: Icon(
                                  _ocultarPin
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (_) {
                              if (!_verificandoPin) {
                                _verificarPin();
                              }
                            },
                          ),

                          if (_erro != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _erro!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _verificandoPin ? null : _verificarPin,
                              icon: _verificandoPin
                                  ? const SizedBox(
                                      width: 19,
                                      height: 19,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.lock_open_outlined),
                              label: const Text('Desbloquear'),
                            ),
                          ),

                          if (_biometriaAtivada && _biometriaDisponivel) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _autenticando
                                  ? null
                                  : _autenticarBiometria,
                              icon: const Icon(Icons.fingerprint),
                              label: Text(
                                _autenticando
                                    ? 'Verificando...'
                                    : 'Usar biometria',
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          TextButton.icon(
                            onPressed: _sairDaConta,
                            icon: const Icon(Icons.logout),
                            label: const Text('Sair da conta'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
