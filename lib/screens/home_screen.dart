import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend_service.dart';
import 'chat_screen.dart';
import 'owner_panel_screen.dart';
import 'study_editor_screen.dart';

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
    try {
      final user = BackendService.currentUser;
      if (user != null) {
        final p = await BackendService.client.from('profiles').select('display_name,plan_code').eq('id', user.id).maybeSingle();
        final c = await BackendService.loadAppConfig();
        admin = await BackendService.isCurrentUserAdmin();
        displayName = p?['display_name']?.toString() ?? '';
        plan = p?['plan_code']?.toString() ?? 'free';
        announcement = c['announcement']?.toString() ?? '';
      }
    } catch (_) {} finally { if (mounted) setState(() => loading = false); }
  }
  void openChat([String? prompt]) => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(initialPrompt: prompt)));\n  void openSupportAssistant() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen(supportMode: true)));
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
    _tile(Icons.chat, 'شروع گفتگو با هوش مصنوعی', 'چت متنی با وارنیکس', () => openChat()),\n    _tile(Icons.support_agent, 'دستیار راهنمای وارنیکس', 'پاسخ به سؤالات و حل مشکلات خود برنامه', openSupportAssistant),

    _tile(Icons.widgets, 'ابزارهای هوشمند', 'نگارش، خلاصه‌سازی، ترجمه و برنامه‌نویسی', () => setState(() => tab = 1)),
    _tile(Icons.workspace_premium, 'مشاهده پلن‌ها', 'امکانات اشتراک رایگان و حرفه‌ای', () => setState(() => tab = 2)),
  ]);
  Widget _tools() {
    final items = [
      ['نگارش و بازنویسی','متن را بنویس یا بهترش کن','لطفاً متن زیر را حرفه‌ای بازنویسی کن: ',Icons.edit_note],
      ['خلاصه‌ساز','خلاصه‌کردن متن و درس','متن زیر را به‌صورت نکته‌ای خلاصه کن: ',Icons.summarize],
      ['مترجم','ترجمه و توضیح متن','متن زیر را ترجمه کن و توضیح بده: ',Icons.translate],
      ['ایده‌پرداز','ایده و راه‌حل','برای موضوع زیر ایده‌های کاربردی بده: ',Icons.lightbulb_outline],
      ['دستیار برنامه‌نویسی','کمک در کدنویسی','به‌عنوان دستیار برنامه‌نویسی راهنمایی‌ام کن: ',Icons.code],
      ['دستیار درسی','توضیح مفاهیم و تمرین','مثل یک معلم، این مبحث را ساده و مرحله‌ای آموزش بده: ',Icons.school],
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('ابزارهای وارنیکس', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ...items.map((e) => _tile(e[3] as IconData, e[0] as String, e[1] as String, () => openChat(e[2] as String))),
      _tile(Icons.edit_document, 'دفتر تایپ و درس', 'قلم، اندازه متن و فاصله خطوط', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyEditorScreen()))),
    ]);
  }
  Widget _plans() => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('پلن‌های وارنیکس', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    _planCard('رایگان','۰ تومان','دسترسی پایه به گفتگو و ابزارهای متنی',plan == 'free'),
    _planCard('حرفه‌ای','قیمت از پنل مالک تعیین می‌شود','برای استفاده بیشتر و دسترسی‌های پیشرفته؛ خرید تا اتصال درگاه غیرفعال است.',plan == 'pro'),
    const Text('توجه: ویژگی‌ها و سقف مصرف هر پلن باید در سرور هم اعمال شوند؛ نمایش این کارت به‌تنهایی خرید یا ارتقای پلن انجام نمی‌دهد.', style: TextStyle(color: Colors.white60)),
  ]);
  Widget _account() => ListView(padding: const EdgeInsets.all(18), children: [
    const CircleAvatar(radius: 34, child: Icon(Icons.person, size: 36)),
    const SizedBox(height: 12), Text(BackendService.currentUser?.email ?? 'حساب کاربری', textAlign: TextAlign.center),
    const SizedBox(height: 10), Text('پلن فعلی: ${plan == 'pro' ? 'حرفه‌ای' : 'رایگان'}', textAlign: TextAlign.center),
    if (admin) _tile(Icons.admin_panel_settings, 'پنل مالک', 'مدیریت برنامه', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerPanelScreen()))),
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
  @override
  void initState() { super.initState(); _read(); }
  Future<void> _read() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() { size = p.getDouble('varnix_font_size') ?? 16; spacing = p.getDouble('varnix_line_spacing') ?? 1.5; font = p.getString('varnix_font') ?? 'پیش‌فرض'; theme = p.getString('varnix_theme') ?? 'تیره'; compact = p.getBool('varnix_compact') ?? false; });
  }
  Future<void> _createOpenRouterKey() async {
    if (keyLoading) return;
    setState(() => keyLoading = true);
    try {
      final result = await BackendService.createOpenRouterUserKey();
      if (!mounted) return;
      final apiKey = result['key'] as String;
      final limit = result['limit_usd']?.toString() ?? '1';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('کلید اختصاصی OpenRouter ساخته شد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('این کلید فقط همین یک‌بار نمایش داده می‌شود. آن را در جای امن ذخیره کن و برای دیگران نفرست. ساخت کلید جدید، کلید قبلی وارنیکس را غیرفعال می‌کند. مصرف از اعتبار OpenRouter وارنیکس کم می‌شود.'),
                const SizedBox(height: 14),
                SelectableText(apiKey, textDirection: TextDirection.ltr),
                const SizedBox(height: 12),
                Text('سقف مصرف روزانه این کلید: $limit دلار'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: apiKey));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('کلید کپی شد.')),
                  );
                }
              },
              child: const Text('کپی کلید'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('متوجه شدم'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    } finally {
      if (mounted) setState(() => keyLoading = false);
    }
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
                Icon(Icons.key_rounded),
                SizedBox(width: 8),
                Expanded(child: Text('کلید API اختصاصی OpenRouter', style: TextStyle(fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 8),
              const Text('یک کلید اختصاصی از حساب OpenRouter وارنیکس دریافت کن و در ابزارهای سازگار استفاده کن. سقف پیش‌فرض روزانه ۱ دلار است و ساخت کلید جدید هر ۲۴ ساعت یک‌بار ممکن است. هزینه از اعتبار وارنیکس کم می‌شود.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: keyLoading ? null : _createOpenRouterKey,
                icon: keyLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_link),
                label: Text(keyLoading ? 'در حال ساخت کلید...' : 'ساخت و دریافت کلید API'),
              ),
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
