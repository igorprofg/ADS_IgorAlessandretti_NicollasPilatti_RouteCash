import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';

import '../../home/presentation/home_page.dart';
import '../../users/presentation/register_page.dart';

import '../data/login_request.dart';
import '../providers/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();

  final _senhaController = TextEditingController();

  bool _ocultarSenha = true;
  bool _carregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();

    super.dispose();
  }

  Future<void> _abrirCadastro() async {
    final usuarioCriado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );

    if (!mounted) {
      return;
    }

    if (usuarioCriado == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta criada com sucesso! Faça login para continuar.'),
        ),
      );
    }
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _carregando = true;
    });

    try {
      final repository = ref.read(authRepositoryProvider);

      await repository.login(
        LoginRequest(
          email: _emailController.text.trim(),
          senha: _senhaController.text,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final mensagem = e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
              theme.colorScheme.surface,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 3,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    children: [
                      // -------------------------
                      // CABEÇALHO / LOGO
                      // -------------------------
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryDark,
                              AppTheme.primaryBright,
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/route_cash_logo.png',
                              height: 78,
                              fit: BoxFit.contain,
                            ),

                            const SizedBox(height: 16),

                            const Text(
                              'Sua rota. Seus ganhos. Seu controle.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // -------------------------
                      // FORMULÁRIO
                      // -------------------------
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Bem-vindo!',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),

                              const SizedBox(height: 5),

                              Text(
                                'Entre na sua conta para continuar.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),

                              const SizedBox(height: 26),

                              TextFormField(
                                controller: _emailController,
                                enabled: !_carregando,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'E-mail',
                                  hintText: 'seuemail@exemplo.com',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Informe seu e-mail.';
                                  }

                                  final emailRegex = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  );

                                  if (!emailRegex.hasMatch(value.trim())) {
                                    return 'Informe um e-mail válido.';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _senhaController,
                                enabled: !_carregando,
                                obscureText: _ocultarSenha,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    tooltip: _ocultarSenha
                                        ? 'Mostrar senha'
                                        : 'Ocultar senha',
                                    onPressed: () {
                                      setState(() {
                                        _ocultarSenha = !_ocultarSenha;
                                      });
                                    },
                                    icon: Icon(
                                      _ocultarSenha
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Informe sua senha.';
                                  }

                                  return null;
                                },
                                onFieldSubmitted: (_) {
                                  if (!_carregando) {
                                    _entrar();
                                  }
                                },
                              ),

                              const SizedBox(height: 5),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _carregando
                                      ? null
                                      : () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Recuperação de senha será implementada posteriormente.',
                                              ),
                                            ),
                                          );
                                        },
                                  child: const Text('Esqueceu sua senha?'),
                                ),
                              ),

                              const SizedBox(height: 12),

                              SizedBox(
                                height: 52,
                                child: FilledButton.icon(
                                  onPressed: _carregando ? null : _entrar,
                                  icon: _carregando
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.login),
                                  label: Text(
                                    _carregando ? 'Entrando...' : 'Entrar',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 22),

                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: theme.dividerColor),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'ou',
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: theme.dividerColor),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              OutlinedButton.icon(
                                onPressed: _carregando ? null : _abrirCadastro,
                                icon: const Icon(
                                  Icons.person_add_alt_1_outlined,
                                ),
                                label: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 13),
                                  child: Text('Criar uma conta'),
                                ),
                              ),

                              const SizedBox(height: 18),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_done_outlined,
                                    size: 15,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Após o primeiro acesso, seus dados ficam disponíveis offline.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
