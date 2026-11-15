import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_settings.dart';

class BackendService {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gwhlihrijgpdvcpleodi.supabase.co',
  );
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_Wjg9U_WILevZ_68fHwXd6Q_RDf0C8Y0',
  );

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: publishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static Future<AppSettings> loadRemoteSettings(AppSettings fallback) async {
    try {
      final row = await client
          .from('app_config')
          .select('app_name,default_model,system_prompt,rubika_url,myket_url,pro_price,pro_base_price')
          .eq('id', true)
          .maybeSingle();
      if (row == null) return fallback;

      final displayedPrice = (row['pro_price'] as String?)?.trim();
      final basePrice = row['pro_base_price'];
      final price = displayedPrice != null && displayedPrice.isNotEmpty
          ? displayedPrice
          : (basePrice == null ? fallback.paymentAmount : '${basePrice.toString()} تومان');

      return fallback.copyWith(
        aiName: row['app_name'] as String? ?? fallback.aiName,
        model: row['default_model'] as String? ?? fallback.model,
        systemPrompt: row['system_prompt'] as String? ?? fallback.systemPrompt,
        rubikaChannelLink: row['rubika_url'] as String? ?? fallback.rubikaChannelLink,
        myketLink: row['myket_url'] as String? ?? fallback.myketLink,
        paymentAmount: price,
      );
    } catch (_) {
      // Keep the last locally saved settings if the network is temporarily unavailable.
      return fallback;
    }
  }
}
