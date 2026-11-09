import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform.dart';
import '../providers/platform_providers.dart';

class PlatformFormPage extends ConsumerStatefulWidget {
  final Platform? platform;

  const PlatformFormPage({super.key, this.platform});

  @override
  ConsumerState<PlatformFormPage> createState() => _PlatformFormPageState();
}

class _PlatformFormPageState extends ConsumerState<PlatformFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();

  bool _salvando = false;

  bool get _editando => widget.platform != null;

  bool get _padrao => widget.platform?.padrao ?? false;

  @override
  void initState() {
    super.initState();

    final platform = widget.platform;

    if (platform != null) {
      _nomeController.text = platform.nome;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();

    super.dispose();
  }

  String? _validarNome(String? value) {
    final nome = value?.trim() ?? '';

    if (nome.isEmpty) {
      return 'Informe o nome da plataforma.';
    }

    if (nome.length > 60) {
      return 'O nome deve ter no máximo 60 caracteres.';
    }

    return null;
  }

  Future<void> _salvar() async {
    if (_padrao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O nome de uma plataforma padrão não pode ser alterado.',
          ),
        ),
      );

      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _salvando = true;
    });

    try {
      final repository = ref.read(platformRepositoryProvider);

      final nome = _nomeController.text.trim();

      if (_editando) {
        await repository.update(widget.platform!.idPlataforma, nome);
      } else {
        await repository.create(nome);
      }

      if (!mounted) {
        return;
      }

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
        title: Text(_editando ? 'Editar plataforma' : 'Nova plataforma'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editando
                    ? 'Atualize os dados da plataforma.'
                    : 'Cadastre uma plataforma utilizada para registrar seus ganhos.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 22),

              if (_padrao) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Esta é uma plataforma padrão do sistema. '
                          'O nome não pode ser alterado. '
                          'Ela pode ser ativada ou inativada pela lista de plataformas.',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _nomeController,
                enabled: !_salvando && !_padrao,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                inputFormatters: [LengthLimitingTextInputFormatter(60)],
                decoration: const InputDecoration(
                  labelText: 'Nome da plataforma',
                  prefixIcon: Icon(Icons.phone_android_outlined),
                  helperText: 'Até 60 caracteres',
                  border: OutlineInputBorder(),
                ),
                validator: _validarNome,
                onFieldSubmitted: (_) {
                  if (!_salvando && !_padrao) {
                    _salvar();
                  }
                },
              ),

              const SizedBox(height: 24),

              if (!_padrao)
                FilledButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _editando
                              ? Icons.save_outlined
                              : Icons.add_circle_outline,
                        ),
                  label: Text(
                    _salvando
                        ? 'Salvando...'
                        : _editando
                        ? 'Salvar alterações'
                        : 'Cadastrar plataforma',
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Voltar'),
                ),

              const SizedBox(height: 12),

              if (!_padrao)
                Text(
                  'A plataforma será salva no aparelho e '
                  'sincronizada automaticamente quando houver conexão.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
