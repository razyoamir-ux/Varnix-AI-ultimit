import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../models/app_settings.dart';

class ApiService {
  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String userMessage,
    required AppSettings settings,
    required String apiKey,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('کلید API تنظیم نشده است. لطفاً از پنل مالک وارد کنید.');
    }

    final url = Uri.parse('${settings.apiBaseUrl}/chat/completions');

    final messages = <Map<String, String>>[];

    // System prompt
    if (settings.systemPrompt.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': settings.systemPrompt,
      });
    }

    // History (limit to last 20 messages to keep payload reasonable)
    final recentHistory = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    for (final msg in recentHistory) {
      messages.add({
        'role': msg.role,
        'content': msg.content,
      });
    }

    // Current user message
    messages.add({
      'role': 'user',
      'content': userMessage,
    });

    final body = {
      'model': settings.model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 2048,
    };

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'HTTP-Referer': 'https://varnix.ai',
              'X-Title': 'Varnix AI 2.0',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices[0]['message']['content'] as String?;
          if (content != null && content.isNotEmpty) {
            return content.trim();
          }
        }
        throw Exception('پاسخ خالی از سرور دریافت شد.');
      } else if (response.statusCode == 401) {
        throw Exception('کلید API نامعتبر است. لطفاً آن را بررسی کنید.');
      } else if (response.statusCode == 429) {
        throw Exception('محدودیت نرخ درخواست. کمی صبر کنید و دوباره تلاش کنید.');
      } else if (response.statusCode == 402) {
        throw Exception('اعتبار حساب OpenRouter کافی نیست.');
      } else {
        String errorMsg = 'خطای سرور: ${response.statusCode}';
        try {
          final errData = jsonDecode(response.body);
          if (errData['error'] != null) {
            final err = errData['error'];
            if (err is Map && err['message'] != null) {
              errorMsg = err['message'].toString();
            } else if (err is String) {
              errorMsg = err;
            }
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } on http.ClientException {
      throw Exception('خطا در اتصال به اینترنت. اتصال خود را بررسی کنید.');
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('خطای ناشناخته: $e');
    }
  }
}
