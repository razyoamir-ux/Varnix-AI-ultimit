import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _bg = Color(0xFF0F0F1A);
const _panel = Color(0xFF211936);
const _accent = Color(0xFFA78BFA);

class JsonToolScreen extends StatefulWidget {
  const JsonToolScreen({super.key});

  @override
  State<JsonToolScreen> createState() => _JsonToolScreenState();
}

class _JsonToolScreenState extends State<JsonToolScreen> {
  final _input = TextEditingController();
  String _output = '';
  String _status = 'JSON را وارد کن و مرتب‌سازی یا فشرده‌سازی را بزن.';
  bool _valid = false;

  void _process({required bool pretty}) {
    try {
      final decoded = jsonDecode(_input.text);
      final result = pretty
          ? const JsonEncoder.withIndent('  ').convert(decoded)
          : jsonEncode(decoded);
      setState(() {
        _output = result;
        _valid = true;
        _status = pretty ? 'JSON معتبر است؛ قالب‌بندی انجام شد.' : 'JSON معتبر است؛ متن فشرده شد.';
      });
    } on FormatException catch (e) {
      setState(() {
        _output = '';
        _valid = false;
        _status = 'JSON نامعتبر است: ${e.message} (موقعیت ${e.offset})';
      });
    } catch (e) {
      setState(() {
        _output = '';
        _valid = false;
        _status = 'خطا در پردازش JSON: $e';
      });
    }
  }

  Future<void> _copy() async {
    if (_output.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _output));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خروجی کپی شد.')),
      );
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: const Text('ابزار JSON'), backgroundColor: const Color(0xFF1A1030), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('اعتبارسنجی، مرتب‌سازی و فشرده‌سازی JSON', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            minLines: 8,
            maxLines: 14,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: '{"name":"Varnix","active":true}',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: _panel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: () => _process(pretty: true), icon: const Icon(Icons.format_align_left), label: const Text('مرتب‌سازی')),
            OutlinedButton.icon(onPressed: () => _process(pretty: false), icon: const Icon(Icons.compress), label: const Text('فشرده‌سازی')),
            TextButton.icon(onPressed: () => setState(() { _input.clear(); _output = ''; _status = 'آماده دریافت JSON جدید.'; _valid = false; }), icon: const Icon(Icons.delete_outline), label: const Text('پاک‌کردن')),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(_valid ? Icons.check_circle : Icons.info_outline, color: _valid ? Colors.greenAccent : _accent),
              const SizedBox(width: 8),
              Expanded(child: Text(_status, style: const TextStyle(color: Colors.white70, height: 1.5))),
            ]),
          ),
          if (_output.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Text('خروجی', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              IconButton(onPressed: _copy, icon: const Icon(Icons.copy, color: _accent), tooltip: 'کپی خروجی'),
            ]),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF080B10), borderRadius: BorderRadius.circular(12)),
              child: SelectableText(_output, style: const TextStyle(color: Color(0xFFB9F6CA), fontFamily: 'monospace', fontSize: 12, height: 1.5)),
            ),
          ],
          const SizedBox(height: 12),
          const Text('تمام پردازش‌ها روی گوشی انجام می‌شوند و اطلاعاتت به سرور ارسال نمی‌شود.', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    ),
  );
}

class Base64ToolScreen extends StatefulWidget {
  const Base64ToolScreen({super.key});

  @override
  State<Base64ToolScreen> createState() => _Base64ToolScreenState();
}

class _Base64ToolScreenState extends State<Base64ToolScreen> {
  final _input = TextEditingController();
  String _output = '';
  String _status = 'متن را وارد کن و یکی از عملیات‌ها را انتخاب کن.';

  void _encode() {
    try {
      final result = base64Encode(utf8.encode(_input.text));
      setState(() {
        _output = result;
        _status = 'متن با موفقیت به Base64 تبدیل شد.';
      });
    } catch (e) {
      setState(() { _output = ''; _status = 'خطا در تبدیل متن: $e'; });
    }
  }

  void _decode() {
    try {
      final normalized = _input.text.replaceAll(RegExp(r'\\s+'), '');
      final bytes = base64.decode(base64.normalize(normalized));
      final result = utf8.decode(bytes);
      setState(() {
        _output = result;
        _status = 'Base64 با موفقیت به متن تبدیل شد.';
      });
    } on FormatException catch (e) {
      setState(() {
        _output = '';
        _status = 'رشته Base64 معتبر نیست یا متن UTF-8 نیست: ${e.message}';
      });
    } catch (e) {
      setState(() { _output = ''; _status = 'خطا در رمزگشایی: $e'; });
    }
  }

  Future<void> _copy() async {
    if (_output.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _output));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خروجی کپی شد.')),
      );
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: const Text('تبدیل‌گر Base64'), backgroundColor: const Color(0xFF1A1030), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('رمزگذاری و رمزگشایی متن، با پشتیبانی از حروف فارسی و ایموجی', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            minLines: 6,
            maxLines: 12,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'متن یا رشته Base64 را اینجا وارد کن...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: _panel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: _encode, icon: const Icon(Icons.lock_outline), label: const Text('تبدیل به Base64')),
            OutlinedButton.icon(onPressed: _decode, icon: const Icon(Icons.lock_open), label: const Text('بازکردن Base64')),
            TextButton.icon(onPressed: () => setState(() { _input.clear(); _output = ''; _status = 'آماده دریافت متن جدید.'; }), icon: const Icon(Icons.delete_outline), label: const Text('پاک‌کردن')),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12)),
            child: Text(_status, style: const TextStyle(color: Colors.white70, height: 1.5)),
          ),
          if (_output.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Text('خروجی', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              IconButton(onPressed: _copy, icon: const Icon(Icons.copy, color: _accent), tooltip: 'کپی خروجی'),
            ]),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF080B10), borderRadius: BorderRadius.circular(12)),
              child: SelectableText(_output, style: const TextStyle(color: Color(0xFFB9F6CA), fontFamily: 'monospace', fontSize: 12, height: 1.5)),
            ),
          ],
          const SizedBox(height: 12),
          const Text('نکته: Base64 رمزنگاری امن نیست؛ فقط یک روش کدگذاری متن است. اطلاعات محرمانه را با آن محافظت‌شده فرض نکن.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, height: 1.5)),
          const Text('تمام پردازش‌ها آفلاین و روی گوشی انجام می‌شوند.', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    ),
  );
}
