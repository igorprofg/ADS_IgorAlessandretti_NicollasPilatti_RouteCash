import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';

/// Verifica a autorização offline ASSINADA pelo NestJS.
/// O backend usa: base64url(JSON payload) + '.' + base64url(Ed25519(payloadB64url)).
class OfflineAuthorizationService {
  OfflineAuthorizationService._();

  static const _storage = FlutterSecureStorage();
  static const _prefix = 'routecash_offline_authorization_v1_';

  // Chave PÚBLICA SPKI/DER em base64 gerada junto à chave privada no backend.
  // Passe via --dart-define ou substitua por uma constante pública no código.
  static const String _publicKeySpkiB64 = String.fromEnvironment(
    'OFFLINE_PUBLIC_KEY_B64',
    defaultValue: '',
  );

  static String _storageKey(String userId) => '$_prefix$userId';

  /// Solicita nova autorização ao servidor. Em 403 ou 401, elimina a concessão
  /// local da conta: um cancelamento conhecido não pode continuar autorizado.
  /// Em falha transitória de rede/5xx, conserva a concessão previamente obtida.
  static Future<bool> renovarSilenciosamente() async {
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

      // Jamais armazenar concessão sem conferir assinatura, usuário e validade.
      if (!await _verificarToken(token, userId)) return false;
      await _storage.write(key: _storageKey(userId), value: token);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await _storage.delete(key: _storageKey(userId));
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Pode ser usado sem rede: apenas tokens válidos e assinados são aceitos.
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

  /// Retorna a expiração somente se a autorização local estiver assinada,
  /// pertencer ao usuário atual e ainda estiver válida.
  static Future<DateTime?> expiracaoLocalValida() async {
    final userId = await SecureStorage.getUserId();
    if (userId == null || userId.isEmpty) return null;
    try {
      final token = await _storage.read(key: _storageKey(userId));
      if (token == null || !await _verificarToken(token, userId)) return null;
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

  /// Renova se houver conexão. Se a consulta falhar por rede/servidor,
  /// aceita concessão assinada ainda válida. Em 401/403 a concessão é revogada.
  static Future<bool> autorizarEscrita() async {
    final online = await renovarSilenciosamente();
    if (online) return true;
    return possuiAutorizacaoValida();
  }

  /// Apaga apenas a concessão offline da conta atual; NÃO altera SQLite/outbox.
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
      // Tolerância de 2 minutos para relógio adiantado do aparelho.
      if (issuedAt > now + 120 || expiresAt <= now) return false;
      if (expiresAt <= issuedAt || expiresAt - issuedAt > 7 * 24 * 60 * 60) {
        return false;
      }

      // Node exporta a chave pública em DER/SPKI. Para Ed25519, são 12 bytes
      // de prefixo fixo + 32 bytes da chave pública bruta.
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
        der.sublist(12),
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
