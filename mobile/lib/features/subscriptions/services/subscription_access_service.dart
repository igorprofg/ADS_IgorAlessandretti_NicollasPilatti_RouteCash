import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_authorization_service.dart';

/// Substitui o bloqueio exclusivamente online dos formulários existentes.
class SubscriptionAccessService {
  SubscriptionAccessService._();

  static Future<bool> verificar(WidgetRef ref, BuildContext context) async {
    final permitido = await OfflineAuthorizationService.autorizarEscrita();
    if (!context.mounted) return false;
    if (permitido) return true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Assinatura necessária'),
        content: const Text(
          'Não foi possível confirmar uma autorização válida para novos '
          'lançamentos. Conecte-se à internet para validar sua assinatura. '
          'Seus registros anteriores continuam salvos neste aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
    return false;
  }
}
