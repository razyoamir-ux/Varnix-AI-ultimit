import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/backend_service.dart';
import 'screens/auth_gate.dart';
import 'services/varnix_appearance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackendService.initialize();
  await VarnixAppearance.instance.load();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const VarnixApp());
}

class VarnixApp extends StatelessWidget {
  const VarnixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: VarnixAppearance.instance,
      builder: (context, _) => MaterialApp(
        title: 'Varnix AI 2.0',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fa', 'IR'),
        supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: VarnixAppearance.instance.buildTheme(),
        home: const AuthGate(),
      ),
    );
  }
}
