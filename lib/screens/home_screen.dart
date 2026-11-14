import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
        final prefs = await SharedPreferences.getInstance();
        final selectedProvider = prefs.getString('varnix_provider_id') ?? 'openrouter';
        const secure = FlutterSecureStorage();
        final savedKey = await secure.read(
          key: selectedProvider == 'openrouter'
              ? 'openrouter_user_api_key_${user.id}'
              : 'varnix_provider_api_key_${user.id}_$selectedProvider',
        );
        final openRouterLinked = selectedProvider == 'openrouter'
            ? await OpenRouterAuthService.isConnected(user.id)
            : false;
        needsPersonalKey = (savedKey == null || savedKey.isEmpty) && !openRouterLinked;
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
            Expanded(child: Text('کلید API تنظیم نشده است')),
          ],
        ),
        content: const Text(
          'برای استفاده از هوش مصنوعی، باید یک سرویس API انتخاب کنی و کلید شخصی آن را در تنظیمات وارنیکس ذخیره کنی. '
          'می‌توانی از OpenRouter یا یکی از سرویس‌های دیگر پشتیبانی‌شده استفاده کنی. کلید در حافظه امن همین گوشی نگهداری می‌شود.',
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
            label: const Text('تنظیم سرویس API'),
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
  String providerId = 'openrouter';
  String providerModel = 'openrouter/free';
  String providerKey = '';
  List<String> availableModels = [];
  bool modelsLoading = false;
  final TextEditingController _providerKeyController = TextEditingController();
  final TextEditingController _manualModelController = TextEditingController();
  static const Map<String, Map<String, String>> _providers = {
    'openrouter': {'name': 'OpenRouter', 'url': 'https://openrouter.ai/api/v1'},
    'groq': {'name': 'Groq', 'url': 'https://api.groq.com/openai/v1'},
    'gemini': {'name': 'Google Gemini', 'url': 'https://generativelanguage.googleapis.com/v1beta/openai'},
    'mistral': {'name': 'Mistral AI', 'url': 'https://api.mistral.ai/v1'},
    'deepseek': {'name': 'DeepSeek', 'url': 'https://api.deepseek.com/v1'},
    'together': {'name': 'Together AI', 'url': 'https://api.together.ai/v1'},
    'fireworks': {'name': 'Fireworks AI', 'url': 'https://api.fireworks.ai/inference/v1'},
    'cerebras': {'name': 'Cerebras', 'url': 'https://api.cerebras.ai/v1'},
    'deepinfra': {'name': 'DeepInfra', 'url': 'https://api.deepinfra.com/v1/openai'},
    'cohere': {'name': 'Cohere', 'url': 'https://api.cohere.ai/compatibility/v1'},
    'novita': {'name': 'Novita AI', 'url': 'https://api.novita.ai/openai/v1'},
    'nvidia': {'name': 'NVIDIA NIM', 'url': 'https://integrate.api.nvidia.com/v1'},
    'xai': {'name': 'xAI (Grok)', 'url': 'https://api.x.ai/v1'},
    'openai': {'name': 'OpenAI', 'url': 'https://api.openai.com/v1'},
    'qwen': {'name': 'Qwen / Alibaba DashScope', 'url': 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1'},
    'zai': {'name': 'Z.AI / GLM', 'url': 'https://api.z.ai/api/paas/v4'},
    'moonshot': {'name': 'Moonshot / Kimi', 'url': 'https://api.moonshot.ai/v1'},
    'huggingface': {'name': 'Hugging Face', 'url': 'https://router.huggingface.co/v1'},
    'sambanova': {'name': 'SambaNova', 'url': 'https://api.sambanova.ai/v1'},
    'siliconflow': {'name': 'SiliconFlow', 'url': 'https://api.siliconflow.com/v1'},
    'minimax': {'name': 'MiniMax', 'url': 'https://api.minimax.io/v1'},
  };
  StreamSubscription<Uri>? _linkSubscription;
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _read();
    _loadProviderPrefs();
    _loadOpenRouterStatus();
    _listenForOpenRouterCallback();
  }

  Future<void> _loadProviderPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = BackendService.currentUser!.id;
    final selected = prefs.getString('varnix_provider_id') ?? 'openrouter';
    const secure = FlutterSecureStorage();
    final key = await secure.read(key: selected == 'openrouter'
        ? 'openrouter_user_api_key_$userId'
        : 'varnix_provider_api_key_${userId}_$selected');
    if (!mounted) return;
    setState(() {
      providerId = _providers.containsKey(selected) ? selected : 'openrouter';
      providerModel = prefs.getString('varnix_provider_model') ?? 'openrouter/free';
      providerKey = key ?? '';
      _providerKeyController.text = providerKey;
      _manualModelController.text = providerModel;
    });
  }

  Future<void> _changeProvider(String? value) async {
    if (value == null || !_providers.containsKey(value)) return;
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    final userId = BackendService.currentUser!.id;
    final key = await secure.read(key: value == 'openrouter'
        ? 'openrouter_user_api_key_$userId'
        : 'varnix_provider_api_key_${userId}_$value');
    setState(() {
      providerId = value;
      providerKey = key ?? '';
      _providerKeyController.text = providerKey;
      availableModels = [];
      providerModel = value == 'openrouter' ? 'openrouter/free' : '';
      _manualModelController.text = providerModel;
    });
    await prefs.setString('varnix_provider_id', value);
    await prefs.setString('varnix_provider_model', providerModel);
  }

  Future<void> _fetchProviderModels() async {
    final info = _providers[providerId]!;
    final key = _providerKeyController.text.trim();
    if (providerId != 'openrouter' && key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اول کلید API این سرویس را وارد کن.')),
      );
      return;
    }
    setState(() => modelsLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${info['url']}/models'),
        headers: {
          'Accept': 'application/json',
          if (key.isNotEmpty) 'Authorization': 'Bearer $key',
        },
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('دریافت مدل‌ها ناموفق بود: ${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      final raw = data is Map ? data['data'] : null;
      final ids = raw is List
          ? raw.whereType<Map>().map((item) => item['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty).toSet().toList()..sort()
          : <String>[];
      if (ids.isEmpty) throw Exception('این سرویس فهرست مدل قابل‌خواندن برنگرداند؛ شناسه مدل را دستی وارد کن.');
      if (!mounted) return;
      setState(() {
        availableModels = ids;
        if (!ids.contains(providerModel)) providerModel = ids.first;
        _manualModelController.text = providerModel;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length} مدل دریافت شد.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => modelsLoading = false);
    }
  }

  Future<void> _saveProviderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    final userId = BackendService.currentUser!.id;
    final key = _providerKeyController.text.trim();
    providerModel = availableModels.isNotEmpty
        ? providerModel
        : _manualModelController.text.trim();
    if (providerModel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ابتدا یک مدل انتخاب یا شناسه آن را وارد کن.')),
      );
      return;
    }
    if (providerId != 'openrouter' && key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کلید API این سرویس را وارد کن.')),
      );
      return;
    }
    if (key.isNotEmpty) {
      await secure.write(
        key: providerId == 'openrouter'
            ? 'openrouter_user_api_key_$userId'
            : 'varnix_provider_api_key_${userId}_$providerId',
        value: key,
      );
    }
    await prefs.setString('varnix_provider_id', providerId);
    await prefs.setString('varnix_provider_model', providerModel);
    if (!mounted) return;
    setState(() => providerKey = key);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سرویس و مدل هوش مصنوعی ذخیره شد.')),
    );
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
    _providerKeyController.dispose();
    _manualModelController.dispose();
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
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('انتخاب سرویس و مدل هوش مصنوعی',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 8),
              const Text('از سرویس‌های مختلف استفاده کن. مدل‌ها مستقیماً از فهرست API همان سرویس دریافت می‌شوند؛ کلیدها فقط در حافظه امن همین گوشی ذخیره می‌شوند.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: providerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'ارائه‌دهنده API'),
                items: _providers.entries.map((entry) => DropdownMenuItem(
                  value: entry.key, child: Text(entry.value['name']!),
                )).toList(),
                onChanged: _changeProvider,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _providerKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'کلید API شخصی',
                  hintText: providerId == 'openrouter' ? 'برای OpenRouter اختیاری؛ اتصال OAuth هم قابل استفاده است' : 'کلید API را از سایت رسمی سرویس بگیر',
                ),
                onChanged: (value) => providerKey = value,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: modelsLoading ? null : _fetchProviderModels,
                icon: modelsLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(modelsLoading ? 'در حال دریافت مدل‌ها...' : 'دریافت فهرست مدل‌ها'),
              ),
              if (availableModels.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: availableModels.contains(providerModel) ? providerModel : availableModels.first,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'مدل قابل استفاده'),
                  items: availableModels.map((id) => DropdownMenuItem(
                    value: id, child: Text(id, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) => setState(() => providerModel = value ?? ''),
                ),
              ] else ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _manualModelController,
                  decoration: const InputDecoration(labelText: 'شناسه مدل (در صورت نیاز دستی وارد کن)'),
                  onChanged: (value) => providerModel = value,
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveProviderSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('ذخیره سرویس و مدل'),
                ),
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
