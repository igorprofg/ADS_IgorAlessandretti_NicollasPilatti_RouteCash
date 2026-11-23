import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(),
);

/// Evita que a Home fique indefinidamente em "Verificando assinatura...".
/// Em caso de erro de rede, AsyncValue passa para estado de erro em até 8s.
final assinaturaAtualProvider = FutureProvider<Map<String, dynamic>?>((ref) {
  return ref
      .read(subscriptionRepositoryProvider)
      .buscarAtual()
      .timeout(const Duration(seconds: 8));
});
