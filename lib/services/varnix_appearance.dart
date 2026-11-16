import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VarnixAppearance extends ChangeNotifier {
  VarnixAppearance._();
  static final VarnixAppearance instance = VarnixAppearance._();

  static const palettes = <String, Color>{
    'بنفش وارنیکس': Color(0xFF7C3AED),
    'آبی اقیانوسی': Color(0xFF0284C7),
    'سبز زمردی': Color(0xFF059669),
    'صورتی': Color(0xFFDB2777),
    'نارنجی': Color(0xFFEA580C),
    'قرمز یاقوتی': Color(0xFFDC2626),
    'فیروزه‌ای': Color(0xFF0D9488),
    'طلایی': Color(0xFFCA8A04),
  };

  static const fonts = <String, String>{
    'پیش‌فرض دستگاه': '',
    'سریف': 'serif',
    'سنس': 'sans-serif',
    'تک‌فاصله‌ای': 'monospace',
    'دست‌نویس': 'cursive',
  };

  String paletteName = 'بنفش وارنیکس';
  String fontName = 'پیش‌فرض دستگاه';
  double textScale = 1.0;
  bool compact = false;
  bool _ready = false;
  bool get ready => _ready;

  Color get seed => palettes[paletteName] ?? palettes.values.first;
  String? get fontFamily => (fonts[fontName] ?? '').isEmpty ? null : fonts[fontName];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    paletteName = prefs.getString('appearance_palette') ?? paletteName;
    fontName = prefs.getString('appearance_font') ?? fontName;
    textScale = prefs.getDouble('appearance_text_scale') ?? textScale;
    compact = prefs.getBool('appearance_compact') ?? compact;
    _ready = true;
    notifyListeners();
  }

  Future<void> setPalette(String value) async {
    paletteName = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('appearance_palette', value);
  }

  Future<void> setFont(String value) async {
    fontName = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('appearance_font', value);
  }

  Future<void> setTextScale(double value) async {
    textScale = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble('appearance_text_scale', value);
  }

  Future<void> setCompact(bool value) async {
    compact = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('appearance_compact', value);
  }

  ThemeData buildTheme() {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      primaryColor: seed,
      scaffoldBackgroundColor: const Color(0xFF101018),
      cardColor: const Color(0xFF211936),
      fontFamily: fontFamily,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: fontFamily),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
