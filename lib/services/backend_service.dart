import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared Supabase access. Provider secrets stay in Supabase Edge Function secrets.
class BackendService {
  BackendService._();

  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static Future<void> signOut() => client.auth.signOut();

  static Future<Map<String, dynamic>> loadAppConfig() async {
    final row = await client.from('app_config').select().eq('id', true).maybeSingle();
    return row ?? <String, dynamic>{};
  }

  static Future<bool> isCurrentUserAdmin() async {
    final user = currentUser;
    if (user == null) return false;
    final row = await client.from('profiles').select('role').eq('id', user.id).maybeSingle();
    return row?['role'] == 'admin';
  }

  static Future<Map<String, dynamic>> createOpenRouterUserKey() async {
    final response = await client.functions.invoke(
      'provision-openrouter-key',
      body: <String, dynamic>{},
    );
    final data = response.data;
    if (response.status < 200 || response.status >= 300) {
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'ساخت کلید OpenRouter ناموفق بود (${response.status})';
      throw Exception(message);
    }
    if (data is! Map || data['key'] is! String) {
      throw Exception('پاسخ ساخت کلید معتبر نیست.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<String> sendChat({required List<Map<String, String>> messages, String? assistantId, String? userInstructions, bool supportMode = false}) async {
    const secureStorage = FlutterSecureStorage();
    final userId = currentUser?.id;
    final prefs = await SharedPreferences.getInstance();
    final providerId = prefs.getString('varnix_provider_id') ?? 'openrouter';
    final selectedModel = prefs.getString('varnix_provider_model');
    final personalKey = userId == null ? null : providerId == 'openrouter'
        ? await secureStorage.read(key: 'openrouter_user_api_key_$userId')
        : await secureStorage.read(key: 'varnix_provider_api_key_${userId}_$providerId');
    final FunctionResponse response;
    try {
      response = await client.functions.invoke('chat', body: {
        'messages': messages,
        'provider_id': providerId,
        if (selectedModel != null && selectedModel.isNotEmpty) 'model': selectedModel,
        if (personalKey != null && personalKey.isNotEmpty)
          (providerId == 'openrouter' ? 'openrouter_api_key' : 'provider_api_key'): personalKey,
        if (assistantId != null) 'assistant_id': assistantId,
        if (supportMode) 'support_mode': true,
        if (userInstructions != null && userInstructions.trim().isNotEmpty) 'user_instructions': userInstructions.trim(),
      });
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : details is String && details.trim().isNotEmpty
              ? details
              : 'سرویس هوش مصنوعی خطای ${e.status} برگرداند.';
      throw Exception(message);
    } catch (e) {
      throw Exception('ارتباط با سرور هوش مصنوعی برقرار نشد: $e');
    }
    final data = response.data;
    if (response.status < 200 || response.status >= 300) {
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'خطا در ارتباط با سرویس هوش مصنوعی (${response.status})';
      throw Exception(message);
    }
    if (data is! Map) throw Exception('پاسخ سرور قابل‌خواندن نیست.');
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final content = choices.first['message']?['content'];
      if (content is String && content.trim().isNotEmpty) return content.trim();
    }
    final error = data['error'];
    if (error is Map && error['message'] != null) throw Exception(error['message'].toString());
    throw Exception('پاسخ خالی از سرور دریافت شد.');
  }
}
