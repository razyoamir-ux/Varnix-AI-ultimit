import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CodeLabScreen extends StatefulWidget {
  const CodeLabScreen({super.key});
  @override
  State<CodeLabScreen> createState() => _CodeLabScreenState();
}

class _CodeLabScreenState extends State<CodeLabScreen> {
  String _language = 'python';
  final _code = TextEditingController(text: 'print("Hello from Varnix!")');
  final _stdin = TextEditingController();
  String _output = 'خروجی ترمینال اینجا نمایش داده می‌شود...';
  bool _running = false;

  @override
  void dispose() {
    _code.dispose();
    _stdin.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_code.text.trim().isEmpty || _running) return;
    setState(() {
      _running = true;
      _output = 'در حال ارسال کد برای اجرا...';
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'code-runner',
        body: {
          'language': _language,
          'code': _code.text,
          'stdin': _stdin.text,
        },
      );
      final data = response.data;
      if (data is Map && data['error'] != null) {
        setState(() => _output = data['error'].toString());
      } else if (data is Map) {
        final compile = data['compile'];
        final run = data['run'];
        final compileOutput = compile is Map ? (compile['output'] ?? '').toString() : '';
        final runOutput = run is Map ? (run['output'] ?? '').toString() : '';
        final combined = [compileOutput, runOutput].where((s) => s.trim().isNotEmpty).join('\n');
        final code = run is Map ? run['code'] : (compile is Map ? compile['code'] : null);
        setState(() => _output = '$combined\n\n[کد خروج: ${code ?? 'نامشخص'}]'.trim());
      } else {
        setState(() => _output = 'پاسخ نامعتبر از سرور اجرا دریافت شد.');
      }
    } on FunctionException catch (e) {
      setState(() => _output = 'خطا در سرویس اجرا: ${e.details ?? e.reasonPhrase ?? e.toString()}');
    } catch (e) {
      setState(() => _output = 'خطا در ارتباط: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _changeLanguage(String language) {
    setState(() {
      _language = language;
      _code.text = language == 'python'
          ? 'print("Hello from Varnix!")'
          : 'public class Main {\n    public static void main(String[] args) {\n        System.out.println("Hello from Varnix!");\n    }\n}';
      _output = 'ترمینال ${language == 'python' ? 'Python' : 'Java'} آماده است.';
    });
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFFAA80FF);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1030),
          foregroundColor: Colors.white,
          title: const Text('آزمایشگاه کدنویسی'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('محیط اجرای Python و Java', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'python', label: Text('Python'), icon: Icon(Icons.code)),
                  ButtonSegment(value: 'java', label: Text('Java'), icon: Icon(Icons.coffee)),
                ],
                selected: {_language},
                onSelectionChanged: (v) => _changeLanguage(v.first),
              ),
              const SizedBox(height: 14),
              Row(children: [
                const Expanded(child: Text('ویرایشگر کد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                IconButton(
                  tooltip: 'کپی کد',
                  onPressed: () => Clipboard.setData(ClipboardData(text: _code.text)),
                  icon: const Icon(Icons.copy, color: purple),
                ),
                IconButton(
                  tooltip: 'پاک کردن',
                  onPressed: () => setState(() => _code.clear()),
                  icon: const Icon(Icons.delete_outline, color: Colors.white70),
                ),
              ]),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF171522), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF49366C))),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _code,
                  minLines: 12,
                  maxLines: 22,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(color: Color(0xFFE8DFFF), fontFamily: 'monospace', fontSize: 13, height: 1.45),
                  decoration: const InputDecoration(border: InputBorder.none, hintText: 'کد خود را اینجا بنویسید...', hintStyle: TextStyle(color: Colors.white38)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('ورودی برنامه (stdin)', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              TextField(
                controller: _stdin,
                minLines: 1,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'اختیاری؛ ورودی برنامه را وارد کنید',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true, fillColor: const Color(0xFF211936),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _running ? null : _run,
                icon: _running
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow),
                label: Text(_running ? 'در حال اجرا...' : 'اجرای کد در ترمینال'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6D4CE8), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 18),
              Row(children: [
                const Icon(Icons.terminal, color: purple),
                const SizedBox(width: 8),
                const Expanded(child: Text('ترمینال خروجی', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                TextButton(onPressed: () => setState(() => _output = ''), child: const Text('پاک کردن خروجی')),
              ]),
              Container(
                constraints: const BoxConstraints(minHeight: 130),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF080B10), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF3B3150))),
                child: SelectableText(_output, style: const TextStyle(color: Color(0xFFB9F6CA), fontFamily: 'monospace', fontSize: 12, height: 1.5)),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF211936), borderRadius: BorderRadius.circular(12)),
                child: const Text(
                  'نکته: اجرای کد در محیط ابری انجام می‌شود. نصب بسته‌های دلخواه با pip و دریافت وابستگی‌های Maven هنوز به سرویس اجرای اختصاصی با پشتیبانی از میرورهای ایران نیاز دارد و در این نسخه فعال نشده است.',
                  style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
