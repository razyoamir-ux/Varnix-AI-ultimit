import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class ProviderConnectionsScreen extends StatefulWidget {
  const ProviderConnectionsScreen({super.key});
  @override
  State<ProviderConnectionsScreen> createState() => _ProviderConnectionsScreenState();
}

class _ProviderConnectionsScreenState extends State<ProviderConnectionsScreen> {
  final StorageService storage = StorageService();
  final Map<String, TextEditingController> controllers = {
    'groq': TextEditingController(),
    'gemini': TextEditingController(),
    'openrouter': TextEditingController(),
    'cerebras': TextEditingController(),
  };
  final Map<String, bool> connected = {};
  final Map<String, bool> visible = {};
  final Map<String, bool> busy = {};
  final Map<String, String> labels = {
    'groq': 'Groq',
    'gemini': 'Google Gemini',
    'openrouter': 'OpenRouter',
    'cerebras': 'Cerebras',
  };
  final Map<String, String> urls = {
    'groq': 'https://console.groq.com/keys',
    'gemini': 'https://aistudio.google.com/app/apikey',
    'openrouter': 'https://openrouter.ai/settings/keys',
    'cerebras': 'https://cloud.cerebras.ai/',
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    for (final id in controllers.keys) {
      final key = await storage.getProviderApiKey(id);
      if (!mounted) return;
      setState(() => connected[id] = key != null && key.isNotEmpty);
    }
  }

  Future<void> _save(String id) async {
    final key = controllers[id]!.text.trim();
    if (key.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کلید API معتبر وارد کن.')));
      return;
    }
    setState(() => busy[id] = true);
    try {
      await storage.saveProviderApiKey(id, key);
      controllers[id]!.clear();
      if (!mounted) return;
      setState(() { connected[id] = true; busy[id] = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('کلید ' + labels[id]! + ' روی همین دستگاه ذخیره شد.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => busy[id] = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ذخیره کلید ناموفق بود: ' + e.toString())));
    }
  }

  Future<void> _remove(String id) async {
    await storage.deleteProviderApiKey(id);
    if (!mounted) return;
    setState(() => connected[id] = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('کلید ' + labels[id]! + ' از این دستگاه پاک شد.')));
  }

  @override
  void dispose() {
    for (final c in controllers.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(title: const Text('اتصال سرویس‌های هوش مصنوعی')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(child: Padding(
            padding: EdgeInsets.all(14),
            child: Text('کلید هر سرویس به‌صورت رمزگذاری‌شده در فضای امن همین دستگاه ذخیره می‌شود. کلیدها در دیتابیس وارنیکس یا مخزن برنامه ذخیره نمی‌شوند. برای استفاده از هر سرویس، باید از حساب همان سرویس API Key بسازی.'),
          )),
          const SizedBox(height: 10),
          ...controllers.keys.map((id) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(labels[id]!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                  Chip(
                    label: Text(connected[id] == true ? 'کلید ذخیره شده' : 'متصل نیست'),
                    avatar: Icon(connected[id] == true ? Icons.check_circle : Icons.link_off, size: 16),
                  ),
                ]),
                Text('برای دریافت کلید: ' + urls[id]!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                TextField(
                  controller: controllers[id],
                  obscureText: visible[id] != true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'API Key جدید',
                    hintText: 'کلید را اینجا وارد کن',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => visible[id] = !(visible[id] == true)),
                      icon: Icon(visible[id] == true ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: FilledButton(
                    onPressed: busy[id] == true ? null : () => _save(id),
                    child: Text(busy[id] == true ? 'در حال ذخیره...' : 'ذخیره امن کلید'),
                  )),
                  if (connected[id] == true) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'حذف کلید',
                      onPressed: () => _remove(id),
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                  ],
                ]),
              ]),
            ),
          )),
          const Text('توجه: ذخیره کلید به معنی تأیید اعتبار یا فعال بودن سهمیه رایگان نیست. هر ارائه‌دهنده محدودیت و شرایط خودش را دارد.', style: TextStyle(color: Colors.amberAccent)),
        ],
      ),
    ),
  );
}
