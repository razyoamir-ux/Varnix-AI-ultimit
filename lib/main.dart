import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F0F1A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final configured = _supabaseUrl.startsWith('https://') && _supabaseAnonKey.isNotEmpty;
  if (configured) {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
  }
  runApp(VarnixApp(configured: configured));
}

class VarnixApp extends StatelessWidget {
  final bool configured;
  const VarnixApp({super.key, required this.configured});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Varnix AI',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF7C3AED),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF6366F1),
          surface: Color(0xFF1A1030),
        ),
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      home: configured ? const AuthGate() : const SetupRequiredScreen(),
    );
  }
}

class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.cloud_off, size: 58, color: Color(0xFFA78BFA)),
                SizedBox(height: 18),
                Text('اتصال سرور هنوز تنظیم نشده است',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
                SizedBox(height: 12),
                Text(
                  'برای ساخت نسخه قابل‌استفاده، آدرس پروژه Supabase و کلید عمومی آن باید هنگام Build تنظیم شوند.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
