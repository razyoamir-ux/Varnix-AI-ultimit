import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';

class ApiService {
  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String userMessage,
    String? model,
    String? systemInstruction,
  }) async {
    final recentHistory = history.length > 20
        ? history.sublist(history.length - 20)
        : history;
    final messages = <Map<String, String>>[
      for (final message in recentHistory)
        if (message.role == 'user' || message.role == 'assistant')
          {'role': message.role, 'content': message.content},
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'chat',
        body: {'messages': messages, if (model != null && model.isNotEmpty) 'model': model, if (systemInstruction != null && systemInstruction.trim().isNotEmpty) 'system_instruction': systemInstruction.trim()},
      );
      final dynamic raw = response.data;
      final dynamic data = raw is String ? jsonDecode(raw) : raw;
      if (response.status < 200 || response.status >= 300) {
        final error = data is Map ? data['error'] : null;
        throw Exception(error?.toString() ?? 'خطای سرور: ${response.status}');
      }
      if (data is Map) {
        final choices = data['choices'];
        if (choices is List && choices.isNotEmpty) {
          final message = choices.first['message'];
          final content = message is Map ? message['content'] : null;
          if (content is String && content.trim().isNotEmpty) return content.trim();
        }
        final error = data['error'];
        if (error != null) throw Exception(error.toString());
      }
      throw Exception('پاسخ خالی از سرور دریافت شد.');
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw Exception(details['error'].toString());
      }
      throw Exception('ارتباط با سرور هوش مصنوعی ناموفق بود (کد ${e.status}).');
    } on AuthException {
      throw Exception('نشست حساب منقضی شده است؛ دوباره وارد حساب شو.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('خطای اتصال به سرویس وارنیکس: $e');
    }
  }
}
