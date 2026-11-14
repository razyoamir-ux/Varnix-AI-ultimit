import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class OpenRouterAuthService {
  OpenRouterAuthService._();
  static const _storage = FlutterSecureStorage();
  static String _apiKeyName(String userId) => 'openrouter_user_api_key_$userId';
  static String _verifierName(String userId) => 'openrouter_oauth_code_verifier_$userId';
  static const callbackUrl = 'com.varnix.ai://login-callback';

  static Future<bool> isConnected(String userId) async =>
      (await _storage.read(key: _apiKeyName(userId)))?.isNotEmpty ?? false;

  static Future<String?> readApiKey(String userId) => _storage.read(key: _apiKeyName(userId));

  static Future<void> beginAuthorization(String userId) async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final verifier = base64Url.encode(bytes).replaceAll('=', '');
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    await _storage.write(key: _verifierName(userId), value: verifier);

    final url = Uri.https('openrouter.ai', '/auth', {
      'callback_url': callbackUrl,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) {
      await _storage.delete(key: _verifierName(userId));
      throw Exception('باز کردن صفحه امن OpenRouter ممکن نشد.');
    }
  }

  static Future<bool> handleCallback(Uri uri, String userId) async {
    if (uri.scheme != 'com.varnix.ai' || uri.host != 'login-callback') return false;
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception(uri.queryParameters['error_description'] ??
          uri.queryParameters['error'] ?? 'اتصال OpenRouter لغو شد.');
    }
    final verifier = await _storage.read(key: _verifierName(userId));
    if (verifier == null || verifier.isEmpty) {
      throw Exception('درخواست اتصال معتبر نیست؛ دوباره تلاش کن.');
    }
    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/auth/keys'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'code_verifier': verifier,
        'code_challenge_method': 'S256',
      }),
    );
    await _storage.delete(key: _verifierName);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('تأیید حساب OpenRouter ناموفق بود (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    final key = decoded is Map ? decoded['key'] : null;
    if (key is! String || !key.startsWith('sk-or-')) {
      throw Exception('OpenRouter کلید معتبر برنگرداند.');
    }
    await _storage.write(key: _apiKeyName(userId), value: key);
    return true;
  }

  static Future<void> disconnect(String userId) async {
    await _storage.delete(key: _apiKeyName(userId));
    await _storage.delete(key: _verifierName(userId));
  }
}
