import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';

const _toolsPanel = Color(0xFF211936);
const _toolsAccent = Color(0xFFA78BFA);

class OnlineToolsScreen extends StatefulWidget {
  const OnlineToolsScreen({super.key});
  @override
  State<OnlineToolsScreen> createState() => _OnlineToolsScreenState();
}
class _OnlineToolsScreenState extends State<OnlineToolsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text('آموزش‌ها و امکانات آنلاین'),
        backgroundColor: const Color(0xFF1A1030),
        foregroundColor: Colors.white,
        bottom: TabBar(controller: _tabs, isScrollable: true, tabs: const [
          Tab(text: 'آموزش‌ها'), Tab(text: 'قالب‌های هوشمند'), Tab(text: 'افزونه‌ها'),
        ]),
      ),
      body: TabBarView(controller: _tabs, children: const [_TutorialsTab(), _PromptsTab(), _AddonsTab()]),
    ),
  );
}

class _TutorialsTab extends StatelessWidget {
  const _TutorialsTab();
  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client.from('tutorials')
      .select('id,title,category,body,image_url,video_url')
      .eq('is_published', true).order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _load(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const _OnlineMessage('آموزش‌ها دریافت نشدند. اتصال اینترنت و تنظیمات دیتابیس را بررسی کن.');
      final rows = snapshot.data ?? [];
      if (rows.isEmpty) return const _OnlineMessage('هنوز آموزشی منتشر نشده است.');
      return ListView(
        padding: const EdgeInsets.all(14),
        children: rows.map((row) {
          final childWidgets = <Widget>[
            SelectableText(row['body']?.toString() ?? '', style: const TextStyle(color: Colors.white, height: 1.8)),
          ];
          final imageUrl = row['image_url']?.toString() ?? '';
          final videoUrl = row['video_url']?.toString() ?? '';
          if (imageUrl.startsWith('https://')) childWidgets.add(TextButton.icon(
            onPressed: () => _openSecureUrl(imageUrl), icon: const Icon(Icons.image_outlined), label: const Text('مشاهده تصویر آموزشی')));
          if (videoUrl.startsWith('https://')) childWidgets.add(TextButton.icon(
            onPressed: () => _openSecureUrl(videoUrl), icon: const Icon(Icons.play_circle_outline), label: const Text('مشاهده ویدئوی آموزشی')));
          return Card(
            color: _toolsPanel,
            child: ExpansionTile(
              title: Text(row['title']?.toString() ?? 'آموزش', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(row['category']?.toString() ?? 'عمومی', style: const TextStyle(color: Colors.white54)),
              children: [Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: childWidgets))],
            ),
          );
        }).toList(),
      );
    },
  );
}

class _PromptsTab extends StatefulWidget {
  const _PromptsTab();
  @override
  State<_PromptsTab> createState() => _PromptsTabState();
}
class _PromptsTabState extends State<_PromptsTab> {
  String _query = '';
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() { super.initState(); _future = _load(); }
  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client.from('prompt_templates')
      .select('id,title,category,prompt').eq('is_published', true).order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }
  void _use(Map<String, dynamic> item) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(initialPrompt: item['prompt']?.toString() ?? '')));
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const _OnlineMessage('قالب‌ها دریافت نشدند. اتصال اینترنت را بررسی کن.');
      final rows = (snapshot.data ?? []).where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        final prompt = (item['prompt'] ?? '').toString().toLowerCase();
        return title.contains(_query.toLowerCase()) || prompt.contains(_query.toLowerCase());
      }).toList();
      return Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'جست‌وجوی قالب...', prefixIcon: const Icon(Icons.search),
              filled: true, fillColor: _toolsPanel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: rows.isEmpty ? const _OnlineMessage('قالبی با این مشخصات پیدا نشد.') : ListView(
            padding: const EdgeInsets.all(12),
            children: rows.map((item) => Card(
              color: _toolsPanel,
              child: ListTile(
                title: Text(item['title']?.toString() ?? 'قالب', style: const TextStyle(color: Colors.white)),
                subtitle: Text(item['category']?.toString() ?? 'عمومی', style: const TextStyle(color: Colors.white60)),
                trailing: IconButton(onPressed: () => _use(item), icon: const Icon(Icons.chat, color: _toolsAccent)),
              ),
            )).toList(),
          ),
        ),
      ]);
    },
  );
}

class _AddonsTab extends StatelessWidget {
  const _AddonsTab();
  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client.from('addons')
      .select('id,slug,name,description,capability_type,config,requires_pro')
      .eq('is_enabled', true).order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }
  Future<void> _activate(BuildContext context, Map<String, dynamic> item) async {
    if (item['requires_pro'] == true) {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برای استفاده از این افزونه وارد حساب شو.')));
        return;
      }
      try {
        final profile = await client.from('profiles').select('role,plan_code,plan_expires_at').eq('id', user.id).maybeSingle();
        final role = (profile?['role'] ?? '').toString().toLowerCase();
        final plan = (profile?['plan_code'] ?? 'free').toString().toLowerCase();
        final expiry = profile?['plan_expires_at'];
        final expiryDate = expiry == null ? null : DateTime.tryParse(expiry.toString());
        final active = role == 'admin' || plan == 'owner' || (plan == 'pro' && (expiryDate == null || expiryDate.isAfter(DateTime.now())));
        if (!active) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('این افزونه مخصوص اشتراک حرفه‌ای است.')));
          return;
        }
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وضعیت اشتراک بررسی نشد؛ دوباره تلاش کن.')));
        return;
      }
    }
    final configValue = item['config'];
    final config = configValue is Map ? Map<String, dynamic>.from(configValue) : <String, dynamic>{};
    final type = item['capability_type']?.toString() ?? '';
    if (type == 'external_link') {
      final url = config['url']?.toString() ?? '';
      if (url.startsWith('https://')) await _openSecureUrl(url);
      return;
    }
    final body = (config['body'] ?? config['content'] ?? '').toString();
    if (type == 'remote_content' && body.isNotEmpty) {
      showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        backgroundColor: _toolsPanel,
        title: Text(item['name']?.toString() ?? 'محتوای افزونه'),
        content: SingleChildScrollView(child: SelectableText(body, style: const TextStyle(color: Colors.white))),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('بستن'))],
      ));
    }
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _load(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const _OnlineMessage('افزونه‌ها بارگذاری نشدند. اتصال اینترنت را بررسی کن.');
      final rows = snapshot.data ?? [];
      if (rows.isEmpty) return const _OnlineMessage('هنوز افزونه‌ای منتشر نشده است.');
      return ListView(
        padding: const EdgeInsets.all(14),
        children: rows.map((item) => Card(
          color: _toolsPanel,
          child: ListTile(
            title: Text(item['name']?.toString() ?? 'افزونه', style: const TextStyle(color: Colors.white)),
            subtitle: Text(item['description']?.toString() ?? '', style: const TextStyle(color: Colors.white60)),
            trailing: IconButton(onPressed: () => _activate(context, item), icon: const Icon(Icons.open_in_new, color: _toolsAccent)),
          ),
        )).toList(),
      );
    },
  );
}

class _OnlineMessage extends StatelessWidget {
  const _OnlineMessage(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
  ));
}

Future<void> _openSecureUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && uri.scheme == 'https') await launchUrl(uri, mode: LaunchMode.externalApplication);
}
