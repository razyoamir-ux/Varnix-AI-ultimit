import 'package:flutter/services.dart';

class MyketBillingService {
  static const MethodChannel _channel =
      MethodChannel('com.varnix.ai.ultimateplus/myket');

  static Future<void> initialize() async {
    await _channel.invokeMethod<Map<dynamic, dynamic>>('initialize');
  }

  static Future<bool> isSubscriptionActive() async {
    final response = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('querySubscription');
    return response?['active'] == true;
  }

  static Future<bool> purchaseSubscription() async {
    final response = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('purchaseSubscription');
    return response?['active'] == true;
  }
}
