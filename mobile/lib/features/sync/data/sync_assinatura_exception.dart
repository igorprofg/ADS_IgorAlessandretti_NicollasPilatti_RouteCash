class SyncAssinaturaException implements Exception {
  final String mensagem;

  const SyncAssinaturaException([
    this.mensagem =
        'Sua assinatura está inativa. Seus lançamentos '
        'permanecem salvos no dispositivo.',
  ]);

  @override
  String toString() => mensagem;
}
