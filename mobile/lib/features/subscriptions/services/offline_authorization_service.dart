import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Verifica a autorizacao offline assinada pelo NestJS.
/// Formato do token: base64url(JSON payload) + '.' + base64url(Ed25519(payloadB64url)).
class OfflineAuthorizationService {
  OfflineAuthorizationService._();

  static const _storage = FlutterSecureStorage();
  static const _prefix = 'routecash_offline_authorization_v1_';

  /// Chave publica Ed25519 em formato SPKI/DER, codificada em Base64.
  /// Deve ser fornecida na compilacao via --dart-define=OFFLINE_PUBLIC_KEY_B64=...
  /// Nunca incluir a chave PRIVADA do backend no aplicativo.
  static const String _publicKeySpkiB64 = String.fromEnvironment(
    'OFFLINE_PUBLIC_KEY_B64',
    defaultValue: '',
  );

  static String _storageKey(String userId) => '$_prefix$userId';

  /// Solicita uma nova autorizacao ao backend.
  /// Em 401/403, descarta o token local; em falha de rede/5xx, preserva-o.
  static Future<bool> renovarSilenciosamente() async {
    // DIAGNÓSTICO TEMPORÁRIO
    debugPrint(
      '[OFFLINE AUTH] Chave pública configurada: '
      '${_publicKeySpkiB64.isNotEmpty}',
    );
    final userId = await SecureStorage.getUserId();
    if (userId == null || userId.isEmpty) return false;

    try {
      final response = await DioClient.instance
          .get<dynamic>(
            '/assinaturas/autorizacao-offline',
            options: Options(
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.data is! Map) return false;

      final data = Map<String, dynamic>.from(response.data as Map);
      final token = data['token_offline'];

      if (data['autorizado'] != true || token is! String) return false;

      // Nao grava uma autorizacao sem validar assinatura, usuario e prazo.
      final tokenValido = await _verificarToken(token, userId);

      debugPrint(
        '[OFFLINE AUTH] Token recebido. '
        'Assinatura válida: $tokenValido',
      );

      if (!tokenValido) return false;

      await _storage.write(key: _storageKey(userId), value: token);
      return true;
    } on DioException catch (e) {
      // Uma negativa explicita do servidor revoga a concessao local.
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await _storage.delete(key: _storageKey(userId));
      }
      return false;
    } catch (_) {
      // Falhas transitorias nao removem a ultima autorizacao valida.
      return false;
    }
  }

  /// Funciona sem acesso a rede, desde que o token local esteja valido.
  static Future<bool> possuiAutorizacaoValida() async {
    final userId = await SecureStorage.getUserId();
    if (userId == null || userId.isEmpty) return false;

    try {
      final token = await _storage.read(key: _storageKey(userId));
      if (token == null || token.isEmpty) return false;
      return _verificarToken(token, userId);
    } catch (_) {
      return false;
    }
  }

  /// Expiracao de um token local valido, para exibir o tempo restante.
  /// Retorna null caso nao haja autorizacao ou ela ja tenha expirado.
  static Future<DateTime?> expiracaoLocalValida() async {
    final userId = await SecureStorage.getUserId();
    if (userId == null || userId.isEmpty) return null;

    try {
      final token = await _storage.read(key: _storageKey(userId));
      if (token == null || !await _verificarToken(token, userId)) {
        return null;
      }

      final partes = token.split('.');
      final dados =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(partes.first)),
                ),
              )
              as Map<String, dynamic>;

      return DateTime.fromMillisecondsSinceEpoch(
        (dados['exp'] as int) * 1000,
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Tenta renovar online. Na indisponibilidade do servidor, usa a ultima
  /// autorizacao assinada e nao expirada, por no maximo sete dias.
  static Future<bool> autorizarEscrita() async {
    final online = await renovarSilenciosamente();
    if (online) return true;
    return possuiAutorizacaoValida();
  }

  /// Remove apenas a autorizacao offline do usuario atual.
  /// Nao altera dados de SQLite nem a fila de sincronizacao.
  static Future<void> limparUsuarioAtual() async {
    final userId = await SecureStorage.getUserId();
    if (userId == null || userId.isEmpty) return;
    await _storage.delete(key: _storageKey(userId));
  }

  static Future<bool> _verificarToken(String token, String userId) async {
    if (_publicKeySpkiB64.isEmpty) return false;

    try {
      final parts = token.split('.');
      if (parts.length != 2) return false;

      final encodedPayload = parts[0];
      final payloadBytes = base64Url.decode(
        base64Url.normalize(encodedPayload),
      );
      final signatureBytes = base64Url.decode(base64Url.normalize(parts[1]));
      if (signatureBytes.length != 64) return false;

      final payloadValue = jsonDecode(utf8.decode(payloadBytes));
      if (payloadValue is! Map<String, dynamic>) return false;
      final payload = payloadValue;

      if (payload['v'] != 1 ||
          payload['typ'] != 'routecash-offline' ||
          payload['sub'] != userId ||
          payload['sid'] is! String ||
          (payload['sid'] as String).isEmpty ||
          payload['iat'] is! int ||
          payload['exp'] is! int) {
        return false;
      }

      final issuedAt = payload['iat'] as int;
      final expiresAt = payload['exp'] as int;
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      // Aceita ate 120 segundos de diferenca de relogio na emissao.
      if (issuedAt > now + 120 || expiresAt <= now) return false;

      // Nao aceita uma autorizacao mais longa que sete dias.
      const maxOfflineSeconds = 7 * 24 * 60 * 60;
      if (expiresAt <= issuedAt || expiresAt - issuedAt > maxOfflineSeconds) {
        return false;
      }

      // A chave Ed25519 publica exportada pelo Node possui 12 bytes
      // fixos do envelope SPKI/DER e 32 bytes da chave publica bruta.
      final der = base64.decode(_publicKeySpkiB64);
      const spkiPrefix = [
        0x30,
        0x2a,
        0x30,
        0x05,
        0x06,
        0x03,
        0x2b,
        0x65,
        0x70,
        0x03,
        0x21,
        0x00,
      ];
      if (der.length != 44) return false;
      for (var i = 0; i < spkiPrefix.length; i++) {
        if (der[i] != spkiPrefix[i]) return false;
      }

      final publicKey = SimplePublicKey(
        der.sublist(spkiPrefix.length),
        type: KeyPairType.ed25519,
      );
      return Ed25519().verify(
        utf8.encode(encodedPayload),
        signature: Signature(signatureBytes, publicKey: publicKey),
      );
    } catch (_) {
      return false;
    }
  }
}
