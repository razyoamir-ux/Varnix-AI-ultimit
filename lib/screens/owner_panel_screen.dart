import 'package:flutter/material.dart';
import '../services/backend_service.dart';

class OwnerPanelScreen extends StatefulWidget {
  const OwnerPanelScreen({super.key});
  @override
  State<OwnerPanelScreen> createState() => _OwnerPanelScreenState();
}

class _OwnerPanelScreenState extends State<OwnerPanelScreen> {
  final _name = TextEditingController();
  final _model = TextEditingController();
  final _baseUrl = TextEditingController();
  final _prompt = TextEditingController();
  final _rubika = TextEditingController();
  final _myket = TextEditingController();
  final _price = TextEditingController();
  final _duration = TextEditingController();
  final _announcement = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _allowed = await BackendService.isCurrentUserAdmin();
      if (!_allowed) return;
      final config = await BackendService.loadAppConfig();
      _name.text = config['app_name']?.toString() ?? 'Varnix AI';
      _model.text = config['default_model']?.toString() ?? 'openrouter/free';
      _baseUrl.text = config['api_base_url']?.toString() ?? 'https://openrouter.ai/api/v1';
      _prompt.text = config['system_prompt']?.toString() ?? '';
      _rubika.text = config['rubika_url']?.toString() ?? '';
      _myket.text = config['myket_url']?.toString() ?? '';
      _price.text = config['pro_price']?.toString() ?? '';
      _duration.text = (config['pro_duration_days'] ?? 30).toString();
      _announcement.text = config['announcement']?.toString() ?? '';
    } catch (e) {
      _notify('بارگذاری تنظیمات ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final days = int.tryParse(_duration.text.trim());
    if (days == null || days < 1) {
      _notify('مدت پلن باید عددی بزرگ‌تر از صفر باشد.');
      return;
    }
    if (!_baseUrl.text.trim().startsWith('https://')) {
      _notify('آدرس API باید با https شروع شود.');
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendService.client.from('app_config').update({
        'app_name': _name.text.trim(),
        'default_model': _model.text.trim(),
        'api_base_url': _baseUrl.text.trim(),
        'system_prompt': _prompt.text.trim(),
        'rubika_url': _rubika.text.trim(),
        'myket_url': _myket.text.trim(),
        'pro_price': _price.text.trim(),
        'pro_duration_days': days,
        'announcement': _announcement.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', true);
      if (mounted) {
        _notify('تنظیمات روی سرور ذخیره شد و برای همهٔ کاربران اعمال می‌شود.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _notify('ذخیره‌سازی ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _field(String label, TextEditingController controller, {int lines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: lines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFF252540),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('پنل مدیریت وارنیکس')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_allowed
                ? const Center(child: Text('دسترسی مدیر برای این حساب فعال نیست.'))
                : ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      const Text('تنظیمات عمومی',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      _field('نام برنامه', _name),
                      _field('مدل هوش مصنوعی', _model),
                      _field('آدرس API', _baseUrl),
                      _field('دستورالعمل اصلی هوش مصنوعی', _prompt, lines: 5),
                      _field('لینک کانال روبیکا', _rubika),
                      _field('لینک مایکت', _myket),
                      const Divider(height: 28),
                      const Text('پلن حرفه‌ای',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      _field('قیمت پلن', _price),
                      _field('مدت پلن (روز)', _duration, keyboard: TextInputType.number),
                      _field('اعلان عمومی برای کاربران', _announcement, lines: 3),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const CircularProgressIndicator()
                              : const Text('ذخیره تنظیمات روی سرور'),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _name, _model, _baseUrl, _prompt, _rubika, _myket, _price, _duration, _announcement,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
