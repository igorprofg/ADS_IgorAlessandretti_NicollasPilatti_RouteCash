import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/secure_storage.dart';

import '../../auth/presentation/login_page.dart';
import '../../../core/security/app_lock_service.dart';

import '../../auth/presentation/setup_pin_page.dart';

import '../providers/user_providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();

  Map<String, dynamic>? _usuario;

  bool _carregando = true;
  bool _salvando = false;
  bool _excluindo = false;
  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  bool _carregandoSeguranca = true;
  bool _alterandoSeguranca = false;

  String? _erro;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await Future.wait([_carregarPerfil(), _carregarSeguranca()]);
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();

    super.dispose();
  }

  Future<void> _carregarPerfil() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final repository = ref.read(userRepositoryProvider);

      final usuario = await repository.getMyProfile();

      if (!mounted) {
        return;
      }

      _nomeController.text = usuario['nome']?.toString() ?? '';

      setState(() {
        _usuario = usuario;
        _carregando = false;
        _erro = null;
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

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _salvando = true;
    });

    try {
      final repository = ref.read(userRepositoryProvider);

      final usuario = await repository.updateMyProfile(
        nome: _nomeController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _usuario = usuario;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso.')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

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

  Future<void> _excluirConta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.person_off_outlined, size: 40),
          title: const Text('Encerrar conta'),
          content: const Text(
            'Tem certeza que deseja encerrar sua conta? '
            'Após esta operação, o acesso ao sistema será bloqueado.\n\n'
            'Esta operação exige conexão com a internet.',
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
              child: const Text('Encerrar conta'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() {
      _excluindo = true;
    });

    try {
      final repository = ref.read(userRepositoryProvider);

      final mensagem = await repository.deleteMyAccount();

      // A conta foi encerrada.
      // Não há necessidade de preservar
      // o SQLite desse usuário.
      await AppDatabase.instance.deleteDatabaseFile();

      await AppDatabase.instance.releaseUser();

      await AppLockService().disableLock();

      await SecureStorage.clearSession();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _excluindo = false;
        });
      }
    }
  }

  Future<void> _carregarSeguranca() async {
    try {
      final service = AppLockService();

      final lockEnabled = await service.isLockEnabled();

      final biometricAvailable = await service.canUseBiometrics();

      final biometricEnabled = lockEnabled
          ? await service.isBiometricEnabled()
          : false;

      if (!mounted) {
        return;
      }

      setState(() {
        _lockEnabled = lockEnabled;

        _biometricAvailable = biometricAvailable;

        _biometricEnabled = biometricEnabled;

        _carregandoSeguranca = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregandoSeguranca = false;
      });
    }
  }

  Future<void> _alterarBloqueio(bool enabled) async {
    if (enabled) {
      final configurado = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const SetupPinPage()),
      );

      if (configurado == true) {
        await _carregarSeguranca();
      }

      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.lock_open_outlined),
          title: const Text('Desativar bloqueio?'),
          content: const Text(
            'O PIN e a configuração de biometria deste usuário serão removidos.',
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
              child: const Text('Desativar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() {
      _alterandoSeguranca = true;
    });

    try {
      await AppLockService().disableLock();

      await _carregarSeguranca();
    } finally {
      if (mounted) {
        setState(() {
          _alterandoSeguranca = false;
        });
      }
    }
  }

  Future<void> _alterarBiometria(bool enabled) async {
    if (!_lockEnabled) {
      return;
    }

    setState(() {
      _alterandoSeguranca = true;
    });

    try {
      final service = AppLockService();

      if (enabled) {
        final ok = await service.enableBiometrics();

        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível confirmar a biometria.'),
            ),
          );
        }
      } else {
        await service.disableBiometrics();
      }

      await _carregarSeguranca();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _alterandoSeguranca = false;
        });
      }
    }
  }

  Future<void> _alterarPin() async {
    final alterado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SetupPinPage(isChanging: true)),
    );

    if (alterado == true) {
      await _carregarSeguranca();
    }
  }

  String _tipoUsuario() {
    final tipo = _usuario?['tipo_usuario']?.toString();

    switch (tipo) {
      case 'MOTORISTA':
        return 'Motorista';

      case 'ADMINISTRADOR':
        return 'Administrador';

      default:
        return tipo ?? '';
    }
  }

  String _statusConta() {
    final status = _usuario?['status_conta']?.toString();

    switch (status) {
      case 'ATIVO':
        return 'Ativa';

      case 'SUSPENSO':
        return 'Suspensa';

      case 'BLOQUEADO':
        return 'Bloqueada';

      default:
        return status ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? _buildErro()
          : RefreshIndicator(
              onRefresh: _carregarPerfil,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person_outline,
                            size: 44,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _nomeController,
                        enabled: !_salvando && !_excluindo,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(100),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          prefixIcon: Icon(Icons.person_outline),
                          helperText:
                              'Alterações exigem conexão com a internet.',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final nome = value?.trim() ?? '';

                          if (nome.isEmpty) {
                            return 'Informe seu nome.';
                          }

                          if (nome.length > 100) {
                            return 'O nome deve ter no máximo 100 caracteres.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        initialValue: _usuario?['email']?.toString() ?? '',
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        initialValue: _tipoUsuario(),
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de usuário',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      if (_usuario?['status_conta'] != null) ...[
                        const SizedBox(height: 16),

                        TextFormField(
                          initialValue: _statusConta(),
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Status da conta',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      FilledButton.icon(
                        onPressed: _salvando || _excluindo ? null : _salvar,
                        icon: _salvando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _salvando ? 'Salvando...' : 'Salvar alterações',
                        ),
                      ),

                      const SizedBox(height: 32),

                      const Divider(),

                      const SizedBox(height: 16),

                      Text(
                        'Segurança',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Proteja o acesso aos dados locais do Route Cash.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: _lockEnabled,
                              onChanged:
                                  _carregandoSeguranca || _alterandoSeguranca
                                  ? null
                                  : _alterarBloqueio,
                              secondary: const Icon(Icons.lock_outline),
                              title: const Text('Bloqueio do app'),
                              subtitle: Text(
                                _lockEnabled
                                    ? 'PIN configurado'
                                    : 'Proteção desativada',
                              ),
                            ),

                            const Divider(height: 1),

                            SwitchListTile(
                              value: _biometricEnabled,
                              onChanged:
                                  !_lockEnabled ||
                                      !_biometricAvailable ||
                                      _alterandoSeguranca
                                  ? null
                                  : _alterarBiometria,
                              secondary: const Icon(Icons.fingerprint),
                              title: const Text('Biometria'),
                              subtitle: Text(
                                !_biometricAvailable
                                    ? 'Não disponível neste aparelho'
                                    : _biometricEnabled
                                    ? 'Ativada'
                                    : 'Usar digital ou reconhecimento biométrico',
                              ),
                            ),

                            if (_lockEnabled) ...[
                              const Divider(height: 1),

                              ListTile(
                                enabled: !_alterandoSeguranca,
                                onTap: _alterandoSeguranca ? null : _alterarPin,
                                leading: const Icon(Icons.pin_outlined),
                                title: const Text('Alterar PIN'),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      const Divider(),

                      const SizedBox(height: 16),

                      Text(
                        'Conta',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'O encerramento da conta exige conexão com a internet e bloqueia novos acessos.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: _salvando || _excluindo
                            ? null
                            : _excluirConta,
                        icon: _excluindo
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_off_outlined),
                        label: Text(
                          _excluindo ? 'Encerrando...' : 'Encerrar minha conta',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
            const Icon(Icons.person_off_outlined, size: 54),

            const SizedBox(height: 16),

            Text(_erro!, textAlign: TextAlign.center),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _carregarPerfil,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
