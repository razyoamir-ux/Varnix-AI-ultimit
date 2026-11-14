import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HelpGuideScreen extends StatefulWidget {
  const HelpGuideScreen({super.key});
  @override
  State<HelpGuideScreen> createState() => _HelpGuideScreenState();
}

class _HelpGuideScreenState extends State<HelpGuideScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  final List<_GuideStep> _steps = const [
    _GuideStep(Icons.waving_hand_rounded, 'به وارنیکس خوش آمدی',
      'وارنیکس یک دستیار هوش مصنوعی چندبخشی است. از نوار پایین می‌توانی بین خانه، ابزارها، پلن‌ها و حساب کاربری جابه‌جا شوی.'),
    _GuideStep(Icons.key_rounded, 'اتصال OpenRouter',
      'برای پاسخ‌گرفتن، از تنظیمات خانه حساب OpenRouter شخصی‌ات را وصل کن. ورود در صفحه رسمی OpenRouter انجام می‌شود و کلید API پس از تأیید در فضای امن گوشی ذخیره می‌شود.'),
    _GuideStep(Icons.chat_bubble_outline_rounded, 'شروع گفتگو',
      'از خانه «شروع گفتگو» را بزن، پیام بنویس و ارسال کن. برای گفتگوی تازه دکمه + و برای دیدن گفتگوهای قبلی منوی کناری را باز کن.'),
    _GuideStep(Icons.smart_toy_outlined, 'انتخاب دستیار و مدل',
      'در صفحه گفتگو از منوی بالای صفحه دستیار فعال را انتخاب کن. مدل پیش‌فرض و تنظیمات اصلی هوش مصنوعی از سمت سرور و پنل مالک کنترل می‌شوند.'),
    _GuideStep(Icons.tune_rounded, 'ابزارها و شخصی‌سازی',
      'در بخش ابزارها می‌توانی درخواست‌های آماده برای نگارش، خلاصه‌سازی، ترجمه، ایده‌پردازی و برنامه‌نویسی را اجرا کنی. از منوی گفتگو هم لحن و سبک پاسخ‌ها را شخصی‌سازی کن.'),
    _GuideStep(Icons.history_rounded, 'ذخیره و ادامه گفتگو',
      'گفتگوها و پیام‌ها با حساب کاربری در Supabase ذخیره می‌شوند. با ورود دوباره به همان حساب می‌توانی تاریخچه گفتگوها را باز کنی.'),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('varnix_first_run_guide_seen', true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('راهنمای استفاده از وارنیکس'),
        actions: [TextButton(onPressed: _finish, child: const Text('رد کردن'))],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _steps.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final step = _steps[index];
                return Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 116, height: 116,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF7C3AED).withValues(alpha: .18),
                        ),
                        child: Icon(step.icon, size: 58, color: const Color(0xFFC4B5FD)),
                      ),
                      const SizedBox(height: 30),
                      Text(step.title, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text(step.description, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.9, color: Colors.white70)),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_steps.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _index == i ? 24 : 8, height: 8,
              decoration: BoxDecoration(
                color: _index == i ? const Color(0xFFA78BFA) : Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
            )),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              if (_index > 0)
                OutlinedButton(
                  onPressed: () => _pages.previousPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
                  child: const Text('قبلی'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  if (_index == _steps.length - 1) {
                    _finish();
                  } else {
                    _pages.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
                  }
                },
                child: Text(_index == _steps.length - 1 ? 'شروع کار با وارنیکس' : 'مرحله بعد'),
              ),
            ]),
          ),
        ]),
      ),
    ),
  );
}

class _GuideStep {
  final IconData icon;
  final String title;
  final String description;
  const _GuideStep(this.icon, this.title, this.description);
}
