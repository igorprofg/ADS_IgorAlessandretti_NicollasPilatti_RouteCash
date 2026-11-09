import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/security/app_lock_service.dart';

class SetupPinPage extends StatefulWidget {
  final bool isChanging;

  const SetupPinPage({super.key, this.isChanging = false});

  @override
  State<SetupPinPage> createState() => _SetupPinPageState();
}

class _SetupPinPageState extends State<SetupPinPage> {
  final _formKey = GlobalKey<FormState>();

  final _pinController = TextEditingController();

  final _confirmPinController = TextEditingController();

  final _service = AppLockService();

  bool _salvando = false;
  bool _ocultarPin = true;

  @override
  void dispose() {
    _pinController.dispose();

    _confirmPinController.dispose();

    super.dispose();
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
      await _service.configurePin(_pinController.text);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isChanging
                ? 'PIN alterado com sucesso.'
                : 'Bloqueio do app ativado.',
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isChanging ? 'Alterar PIN' : 'Configurar PIN'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  widget.isChanging
                      ? 'Escolha um novo PIN'
                      : 'Proteja seus dados',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'O PIN será usado para acessar o Route Cash sem encerrar sua sessão.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 32),

                TextFormField(
                  controller: _pinController,
                  enabled: !_salvando,
                  obscureText: _ocultarPin,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    hintText: '4 a 6 números',
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
                  validator: (value) {
                    final pin = value ?? '';

                    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
                      return 'Informe um PIN de 4 a 6 números.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmPinController,
                  enabled: !_salvando,
                  obscureText: _ocultarPin,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Confirmar PIN',
                    counterText: '',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != _pinController.text) {
                      return 'Os PINs não coincidem.';
                    }

                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!_salvando) {
                      _salvar();
                    }
                  },
                ),

                const SizedBox(height: 26),

                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _salvando ? null : _salvar,
                    icon: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _salvando
                          ? 'Salvando...'
                          : widget.isChanging
                          ? 'Alterar PIN'
                          : 'Ativar bloqueio',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
