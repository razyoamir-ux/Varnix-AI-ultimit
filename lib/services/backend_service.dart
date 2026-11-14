import 'package:supabase_flutter/supabase_flutter.dart';

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

  static Future<String> sendChat({required List<Map<String, String>> messages}) async {
    final response = await client.functions.invoke('chat', body: {'messages': messages});
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
