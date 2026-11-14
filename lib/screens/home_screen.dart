import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import '../services/openrouter_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend_service.dart';
import 'chat_screen.dart';
import 'owner_panel_screen.dart';
import 'help_guide_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  bool loading = true, admin = false;
  String displayName = '', plan = 'free', announcement = '';
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    var needsPersonalKey = false;
    try {
      final user = BackendService.currentUser;
      if (user != null) {
        final p = await BackendService.client.from('profiles').select('display_name,plan_code').eq('id', user.id).maybeSingle();
        final c = await BackendService.loadAppConfig();
        admin = await BackendService.isCurrentUserAdmin();
        displayName = p?['display_name']?.toString() ?? '';
        plan = p?['plan_code']?.toString() ?? 'free';
        announcement = c['announcement']?.toString() ?? '';
        needsPersonalKey = !await OpenRouterAuthService.isConnected(user.id);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
    if (mounted) await _showFirstRunGuideIfNeeded();
    if (mounted && needsPersonalKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMissingOpenRouterKeyDialog();
      });
    }
  }

  Future<void> _showFirstRunGuideIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || prefs.getBool('varnix_first_run_guide_seen') == true) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpGuideScreen()));
  }

  Future<void> _showMissingOpenRouterKeyDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF201A35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.key_off_rounded, color: Color(0xFFC4B5FD)),
            SizedBox(width: 10),
            Expanded(child: Text('کلید شخصی OpenRouter نداری')),
          ],
        ),
        content: const Text(
          'برای استفاده از حساب شخصی هوش مصنوعی، هنوز حساب OpenRouter را به وارنیکس وصل نکرده‌ای. '
          'می‌توانی همین حالا از داخل برنامه وارد OpenRouter شوی یا ثبت‌نام کنی؛ '
          'پس از تأیید دسترسی، کلید API به‌صورت خودکار و امن در برنامه ذخیره می‌شود.',
          style: TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('فعلاً نه'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
              );
            },
            icon: const Icon(Icons.link_rounded),
            label: const Text('اتصال حساب OpenRouter'),
          ),
        ],
      ),
    );
  }
  void openChat([String? prompt]) => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(initialPrompt: prompt)));
  void openSupportAssistant() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen(supportMode: true)));
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('Varnix AI ✨'), actions: [
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppSettingsScreen()))),
      ]),
      body: loading ? const Center(child: CircularProgressIndicator()) : IndexedStack(index: tab, children: [
        _home(), _tools(), _plans(), _account(),
      ]),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'خانه'),
        NavigationDestination(icon: Icon(Icons.widgets_outlined), label: 'ابزارها'),
        NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), label: 'پلن‌ها'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'حساب من'),
      ]),
    ),
  );
  Widget _home() => ListView(padding: const EdgeInsets.all(18), children: [
    Text(displayName.isEmpty ? 'سلام، خوش اومدی 👋' : 'سلام $displayName عزیز 👋', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8), const Text('امروز چه کاری از دست وارنیکس برمیاد؟'),
    if (announcement.isNotEmpty) ...[const SizedBox(height: 12), Text(announcement)],
    const SizedBox(height: 20),
    _tile(Icons.chat, 'شروع گفتگو با هوش مصنوعی', 'چت متنی با وارنیکس', () => openChat()),
    _tile(Icons.support_agent, 'دستیار راهنمای وارنیکس', 'پاسخ به سؤالات و حل مشکلات خود برنامه', openSupportAssistant),

    _tile(Icons.widgets, 'ابزارهای هوشمند', 'نگارش، خلاصه‌سازی، ترجمه و برنامه‌نویسی', () => setState(() => tab = 1)),
    _tile(Icons.workspace_premium, 'مشاهده پلن‌ها', 'امکانات اشتراک رایگان و حرفه‌ای', () => setState(() => tab = 2)),
  ]);
  Widget _tools() {
    final items = [
      ['نگارش و بازنویسی','متن را بنویس یا بهترش کن','لطفاً متن زیر را حرفه‌ای بازنویسی کن: ',Icons.edit_note],
      ['خلاصه‌ساز','خلاصه‌کردن متن','متن زیر را به‌صورت نکته‌ای خلاصه کن: ',Icons.summarize],
      ['مترجم','ترجمه و توضیح متن','متن زیر را ترجمه کن و توضیح بده: ',Icons.translate],
      ['ایده‌پرداز','ایده و راه‌حل','برای موضوع زیر ایده‌های کاربردی بده: ',Icons.lightbulb_outline],
      ['دستیار برنامه‌نویسی','کمک در کدنویسی','به‌عنوان دستیار برنامه‌نویسی راهنمایی‌ام کن: ',Icons.code],

    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('ابزارهای وارنیکس', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ...items.map((e) => _tile(e[3] as IconData, e[0] as String, e[1] as String, () => openChat(e[2] as String))),
      _tile(Icons.help_outline, 'راهنمای استفاده از وارنیکس', 'آموزش مرحله‌به‌مرحله قابلیت‌های برنامه', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpGuideScreen()))),
    ]);
  }
  Widget _plans() => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('پلن‌های وارنیکس', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    _planCard('رایگان', '۰ تومان', '۲۰ درخواست در روز • حداکثر ۱٬۰۲۴ توکن برای هر پاسخ • دسترسی پایه', plan == 'free'),
    _planCard('پرو', 'اشتراک پولی', '۱۰۰ درخواست در روز • حداکثر ۲٬۰۴۸ توکن برای هر پاسخ • مناسب استفاده روزمره', plan == 'pro'),
    _planCard('پرو مکس', 'اشتراک پولی', '۳۰۰ درخواست در روز • حداکثر ۴٬۰۹۶ توکن برای هر پاسخ • استفاده سنگین‌تر', plan == 'pro_max'),
    _planCard('اولترا مکس', 'اشتراک پولی', '۸۰۰ درخواست در روز • حداکثر ۸٬۱۹۲ توکن برای هر پاسخ • بالاترین سهمیه', plan == 'ultra_max'),
    const SizedBox(height: 8),
    const Text('سهمیه‌ها در سرور کنترل می‌شوند و هر روز در ساعت ۰۰:۰۰ UTC بازنشانی می‌شوند. خرید پلن‌های پولی تا فعال‌شدن درگاه پرداخت در دسترس نیست.', style: TextStyle(color: Colors.white60)),
  ]);
  Widget _account() => ListView(padding: const EdgeInsets.all(18), children: [
    const CircleAvatar(radius: 34, child: Icon(Icons.person, size: 36)),
    const SizedBox(height: 12), Text(BackendService.currentUser?.email ?? 'حساب کاربری', textAlign: TextAlign.center),
    const SizedBox(height: 10), Text('پلن فعلی: ${{'free': 'رایگان', 'pro': 'پرو', 'pro_max': 'پرو مکس', 'ultra_max': 'اولترا مکس'}[plan] ?? 'رایگان'}', textAlign: TextAlign.center),
    if (admin) _tile(Icons.admin_panel_settings, 'پنل مالک', 'مدیریت برنامه', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerPanelScreen()))),
    _tile(Icons.help_outline, 'راهنمای استفاده از وارنیکس', 'مشاهده دوباره آموزش چندمرحله‌ای', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpGuideScreen()))),
    _tile(Icons.settings, 'تنظیمات ظاهر و فونت', 'شخصی‌سازی تجربه برنامه', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppSettingsScreen()))),
    _tile(Icons.logout, 'خروج از حساب', 'خروج امن', () => BackendService.signOut()),
  ]);
  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(
    color: const Color(0xFF201A35), child: ListTile(leading: Icon(icon, color: const Color(0xFFA78BFA)), title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_left), onTap: onTap));
  Widget _planCard(String title, String price, String desc, bool current) => Card(
    color: const Color(0xFF201A35), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), if (current) const Chip(label: Text('پلن فعلی'))]),
      Text(price, style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 18)), const SizedBox(height: 8), Text(desc),
    ])));
}

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}
class _AppSettingsScreenState extends State<AppSettingsScreen> {
  double size = 16, spacing = 1.5;
  String font = 'پیش‌فرض', theme = 'تیره';
  bool compact = false;
  bool keyLoading = false;
  bool openRouterConnected = false;
  StreamSubscription<Uri>? _linkSubscription;
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _read();
    _loadOpenRouterStatus();
    _listenForOpenRouterCallback();
  }

  Future<void> _loadOpenRouterStatus() async {
    final connected = await OpenRouterAuthService.isConnected(BackendService.currentUser!.id);
    if (mounted) setState(() => openRouterConnected = connected);
  }

  Future<void> _listenForOpenRouterCallback() async {
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleOpenRouterCallback, onError: (_) {});
    final initial = await _appLinks.getInitialLink();
    if (initial != null) await _handleOpenRouterCallback(initial);
  }

  Future<void> _handleOpenRouterCallback(Uri uri) async {
    if (uri.scheme != 'com.varnix.ai' || uri.host != 'login-callback') return;
    if (mounted) setState(() => keyLoading = true);
    try {
      await OpenRouterAuthService.handleCallback(uri, BackendService.currentUser!.id);
      if (!mounted) return;
      setState(() => openRouterConnected = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حساب OpenRouter با موفقیت متصل شد.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => keyLoading = false);
    }
  }

  Future<void> _connectOpenRouter() async {
    if (keyLoading) return;
    setState(() => keyLoading = true);
    try {
      await OpenRouterAuthService.beginAuthorization(BackendService.currentUser!.id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => keyLoading = false);
    }
  }

  Future<void> _disconnectOpenRouter() async {
    await OpenRouterAuthService.disconnect(BackendService.currentUser!.id);
    if (mounted) setState(() => openRouterConnected = false);
  }
  Future<void> _read() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() { size = p.getDouble('varnix_font_size') ?? 16; spacing = p.getDouble('varnix_line_spacing') ?? 1.5; font = p.getString('varnix_font') ?? 'پیش‌فرض'; theme = p.getString('varnix_theme') ?? 'تیره'; compact = p.getBool('varnix_compact') ?? false; });
  }
  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('varnix_font_size', size); await p.setDouble('varnix_line_spacing', spacing);
    await p.setString('varnix_font', font); await p.setString('varnix_theme', theme); await p.setBool('varnix_compact', compact);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تنظیمات ذخیره شد.')));
  }
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('تنظیمات وارنیکس'), actions: [IconButton(onPressed: _save, icon: const Icon(Icons.save))]),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.account_circle_outlined),
                SizedBox(width: 8),
                Expanded(child: Text('اتصال حساب شخصی OpenRouter', style: TextStyle(fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 8),
              const Text(
                'حساب OpenRouter خودت را متصل کن تا درخواست‌های هوش مصنوعی با کلید شخصی تو ارسال شوند و هزینه از اعتبار حساب خودت کم شود. برای ورود یا ثبت‌نام، صفحه رسمی OpenRouter باز می‌شود؛ اگر گزینه Google نمایش داده شد می‌توانی با گوگل وارد شوی. رمز گوگل یا OpenRouter در وارنیکس دریافت نمی‌شود.',
              ),
              const SizedBox(height: 12),
              Row(children: [
                Icon(openRouterConnected ? Icons.check_circle : Icons.link_off,
                    color: openRouterConnected ? Colors.greenAccent : Colors.white54),
                const SizedBox(width: 8),
                Text(openRouterConnected ? 'حساب متصل است' : 'حسابی متصل نشده'),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: keyLoading ? null : _connectOpenRouter,
                  icon: keyLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.login),
                  label: Text(keyLoading ? 'در حال اتصال...' : openRouterConnected ? 'اتصال دوباره' : 'اتصال OpenRouter با Google'),
                ),
                if (openRouterConnected)
                  OutlinedButton.icon(
                    onPressed: keyLoading ? null : _disconnectOpenRouter,
                    icon: const Icon(Icons.link_off),
                    label: const Text('قطع اتصال'),
                  ),
              ]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      const Text('اندازه نوشته', style: TextStyle(fontWeight: FontWeight.bold)), Slider(value: size, min: 12, max: 30, divisions: 18, label: size.round().toString(), onChanged: (v) => setState(() => size = v)),
      const Text('فاصله خطوط', style: TextStyle(fontWeight: FontWeight.bold)), Slider(value: spacing, min: 1, max: 2.5, divisions: 6, label: spacing.toStringAsFixed(1), onChanged: (v) => setState(() => spacing = v)),
      const SizedBox(height: 8), const Text('فونت (در صورت نصب بودن فونت در دستگاه/برنامه)'), DropdownButtonFormField<String>(value: font, items: ['پیش‌فرض','Serif','Monospace'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => font = v ?? 'پیش‌فرض')),
      const SizedBox(height: 12), DropdownButtonFormField<String>(value: theme, items: ['تیره','روشن','مطالعه'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => theme = v ?? 'تیره')),
      SwitchListTile(value: compact, onChanged: (v) => setState(() => compact = v), title: const Text('نمایش فشرده‌تر')),
      const SizedBox(height: 16), const Text('پیش‌نمایش متن', style: TextStyle(fontWeight: FontWeight.bold)),
      Container(padding: const EdgeInsets.all(16), color: const Color(0xFF28233B), child: Text('وارنیکس؛ همراه هوشمند برای نوشتن، یادگیری و برنامه‌ریزی.\nاین یک پیش‌نمایش تنظیمات نوشتاری است.', style: TextStyle(fontSize: size, height: spacing, fontFamily: font == 'Serif' ? 'serif' : font == 'Monospace' ? 'monospace' : null))),
      const SizedBox(height: 20), FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('ذخیره تنظیمات')),
    ]),
  ));
}
