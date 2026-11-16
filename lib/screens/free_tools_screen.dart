import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FreeToolsScreen extends StatefulWidget {
  const FreeToolsScreen({super.key});

  @override
  State<FreeToolsScreen> createState() => _FreeToolsScreenState();
}

class _FreeToolsScreenState extends State<FreeToolsScreen> {
  static const _purple = Color(0xFFAA80FF);
  final _textController = TextEditingController();
  final _noteController = TextEditingController();
  bool _loadingNote = true;
  bool _savingNote = false;

  static const _templates = <Map<String, String>>[
    {
      'title': 'ایده‌پردازی محتوا',
      'prompt': 'برای موضوعی که می‌دهم، ۱۰ ایده خلاقانه و قابل اجرا پیشنهاد بده. برای هر ایده عنوان، مخاطب هدف و مراحل اجرا را بنویس.'
    },
    {
      'title': 'برنامه‌ریزی مطالعه',
      'prompt': 'برای هدف و زمانی که مشخص می‌کنم، یک برنامه مطالعه واقع‌بینانه روزانه با زمان استراحت، مرور و آزمون طراحی کن.'
    },
    {
      'title': 'بررسی و توضیح کد',
      'prompt': 'کد زیر را مرحله‌به‌مرحله بررسی کن، ایرادها و ریسک‌های امنیتی را توضیح بده و نسخه اصلاح‌شده همراه با دلیل تغییرات ارائه کن.'
    },
    {
      'title': 'نوشتن متن حرفه‌ای',
      'prompt': 'متن زیر را روان، دقیق و حرفه‌ای بازنویسی کن. معنی اصلی را حفظ کن و از اضافه‌گویی پرهیز کن.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _noteController.text = prefs.getString('varnix_free_quick_note') ?? '';
    } finally {
      if (mounted) setState(() => _loadingNote = false);
    }
  }

  Future<void> _saveNote() async {
    setState(() => _savingNote = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('varnix_free_quick_note', _noteController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('یادداشت روی همین دستگاه ذخیره شد.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ذخیره یادداشت انجام نشد.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _textController.text;
    final words = text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\\s+')).length;
    final paragraphs = text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\\n\\s*\\n')).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          title: const Text('ابزارهای رایگان وارنیکس'),
          backgroundColor: const Color(0xFF1A1030),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('قالب‌های آماده هوش مصنوعی'),
            const SizedBox(height: 8),
            const Text(
              'با یک لمس، دستور آماده را کپی کن و در گفتگوی وارنیکس استفاده کن.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 12),
            ..._templates.map((item) => Card(
              color: const Color(0xFF211936),
              child: ListTile(
                leading: const Icon(Icons.bolt, color: _purple),
                title: Text(item['title']!, style: const TextStyle(color: Colors.white)),
                subtitle: const Text('کپی دستور آماده', style: TextStyle(color: Colors.white54)),
                trailing: const Icon(Icons.copy, color: _purple),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: item['prompt']!));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('قالب «${item['title']}» کپی شد.')),
                    );
                  }
                },
              ),
            )),
            const SizedBox(height: 20),
            _sectionTitle('بررسی و شمارش متن'),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              minLines: 4,
              maxLines: 7,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'متن را اینجا وارد یا جای‌گذاری کن...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF211936),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _stat('کاراکتر', text.length.toString()),
                const SizedBox(width: 8),
                _stat('کلمه', words.toString()),
                const SizedBox(width: 8),
                _stat('پاراگراف', paragraphs.toString()),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _textController.clear()),
                icon: const Icon(Icons.delete_outline),
                label: const Text('پاک کردن متن'),
              ),
            ),
            const SizedBox(height: 12),
            _sectionTitle('یادداشت سریع'),
            const SizedBox(height: 8),
            const Text(
              'یادداشت‌ها فقط روی همین دستگاه ذخیره می‌شوند و به حساب ابری ارسال نمی‌شوند.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              minLines: 4,
              maxLines: 8,
              enabled: !_loadingNote,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ایده یا یادداشتت را اینجا نگه دار...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF211936),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loadingNote || _savingNote ? null : _saveNote,
              icon: _savingNote
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_savingNote ? 'در حال ذخیره...' : 'ذخیره یادداشت روی دستگاه'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6D4CE8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
  );

  Widget _stat(String label, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF211936),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: _purple, fontWeight: FontWeight.bold, fontSize: 19)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    ),
  );
}
