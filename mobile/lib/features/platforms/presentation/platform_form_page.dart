import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();

    if (widget.platform != null) {
      _nomeController.text = widget.platform!.nome;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

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
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar plataforma' : 'Nova plataforma'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome da plataforma',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome da plataforma.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 24),

              FilledButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _editando
                            ? 'Salvar alterações'
                            : 'Cadastrar plataforma',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
