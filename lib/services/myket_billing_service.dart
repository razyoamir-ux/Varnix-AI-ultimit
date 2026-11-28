import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyketBillingService {
  static const MethodChannel _channel =
      MethodChannel('com.varnix.ai.ultimateplus/myket');

  static Future<void> initialize() async {
    await _channel.invokeMethod<Map<dynamic, dynamic>>('initialize');
  }

  static Future<bool> _verifyReceipt(Map<dynamic, dynamic>? receipt) async {
    if (receipt == null || receipt['active'] != true) return false;

    final originalJson = receipt['originalJson']?.toString() ?? '';
    final signature = receipt['signature']?.toString() ?? '';
    if (originalJson.isEmpty || signature.isEmpty) {
      throw StateError('رسید امضاشده مایکت از دستگاه دریافت نشد.');
    }

    final response = await Supabase.instance.client.functions.invoke(
      'myket-verify',
      body: {
        'action': 'verify',
        'original_json': originalJson,
        'signature': signature,
      },
    );
    final data = response.data;
    if (response.status < 200 || response.status >= 300 ||
        data is! Map || data['error'] != null) {
      final message = data is Map
          ? data['error']?.toString()
          : null;
      throw StateError(message ?? 'اعتبارسنجی خرید در سرور ناموفق بود.');
    }
    return data['verified'] == true && data['active'] == true;
  }

  static Future<bool> isSubscriptionActive() async {
    final response = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('querySubscription');
    return _verifyReceipt(response);
  }

  static Future<bool> purchaseSubscription() async {
    final session = await Supabase.instance.client.functions.invoke(
      'myket-verify',
      body: {'action': 'create'},
    );
    final sessionData = session.data;
    if (session.status < 200 || session.status >= 300 ||
        sessionData is! Map ||
        sessionData['developer_payload'] is! String) {
      final message = sessionData is Map
          ? sessionData['error']?.toString()
          : null;
      throw StateError(message ?? 'ساخت درخواست امن خرید ناموفق بود.');
    }

    final payload = sessionData['developer_payload'] as String;
    final receipt = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'purchaseSubscription',
      {'developerPayload': payload},
    );
    return _verifyReceipt(receipt);
  }
}
