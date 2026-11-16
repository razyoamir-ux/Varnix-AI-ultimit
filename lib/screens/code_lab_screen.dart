import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:varnix_ai/screens/package_library_screen.dart';
import 'package:varnix_ai/screens/code_projects_screen.dart';

class CodeLabScreen extends StatefulWidget {
  const CodeLabScreen({super.key});
  @override
  State<CodeLabScreen> createState() => _CodeLabScreenState();
}

class _CodeLabScreenState extends State<CodeLabScreen> {
  String _language = 'python';
  final _code = TextEditingController(text: 'print("Hello from Varnix!")');
  final _stdin = TextEditingController();
  final _terminalCommand = TextEditingController();
  String _output = 'ترمینال آماده است.';
  bool _running = false;
  bool _installing = false;

  @override
  void dispose() {
    _code.dispose();
    _stdin.dispose();
    _terminalCommand.dispose();
    super.dispose();
  }

  Future<void> _terminalAction() async {
    final command = _terminalCommand.text.trim();
    if (command.isEmpty || _installing) return;
    final match = RegExp(r'^pip\s+install\s+([A-Za-z0-9_.-]+)$', caseSensitive: false).firstMatch(command);
    if (_language == 'python' && match != null) {
      await Clipboard.setData(ClipboardData(text: command));
      if (!mounted) return;
      setState(() => _output = 'دستور نصب کپی شد. Runner ابری وارنیکس موقتی است و نصب بسته را بین اجراها نگه نمی‌دارد؛ دستور را در محیط Python خودت اجرا کن.');
      return;
    }
    if (_language == 'java' && command.startsWith('mvn dependency:get -Dartifact=')) {
      await Clipboard.setData(ClipboardData(text: command));
      if (!mounted) return;
      setState(() => _output = 'دستور Maven کپی شد. نصب مستقیم وابستگی‌ها در Runner فعلی فعال نیست.');
      return;
    }
    if (!mounted) return;
    setState(() => _output = _language == 'python'
        ? 'دستور پشتیبانی‌شده برای کپی: pip install package-name'
        : 'دستور Maven را از صفحه کتابخانه‌ها کپی کن؛ نصب مستقیم Maven هنوز فعال نیست.');
  }

  Future<void> _openSavedProject() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const CodeProjectsScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      _language = result['language']?.toString() == 'java' ? 'java' : 'python';
      _code.text = result['code']?.toString() ?? '';
      _output = 'پروژه «${result['name'] ?? ''}» در ویرایشگر باز شد.';
    });
  }

  Future<void> _saveProject() async {
    final nameController = TextEditingController(text: 'پروژه من');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ذخیره پروژه'),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'نام پروژه')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(ctx, nameController.text.trim()), child: const Text('ذخیره')),
        ],
      ),
    );
    nameController.dispose();
    if (name == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('varnix_code_projects_v1');
    List<dynamic> projects = [];
    if (raw != null) {
      try { projects = List<dynamic>.from(jsonDecode(raw) as List); } catch (_) {}
    }
    projects.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': name.isEmpty ? 'پروژه من' : name,
      'language': _language,
      'code': _code.text,
      'updated': DateTime.now().toIso8601String(),
    });
    await prefs.setString('varnix_code_projects_v1', jsonEncode(projects));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پروژه روی دستگاه ذخیره شد.')));
  }

  Future<void> _run() async {
    if (_code.text.trim().isEmpty || _running) return;
    setState(() { _running = true; _output = 'در حال ارسال کد برای اجرا...'; });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'code-runner',
        body: {'language': _language, 'code': _code.text, 'stdin': _stdin.text},
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
        final exitCode = run is Map ? run['code'] : (compile is Map ? compile['code'] : null);
        setState(() => _output = '${combined.isEmpty ? 'بدون خروجی' : combined}\n\n[کد خروج: ${exitCode ?? 'نامشخص'}]');
      } else {
        setState(() => _output = 'پاسخ نامعتبر از سرویس اجرا دریافت شد.');
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
      _terminalCommand.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFFAA80FF);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(title: const Text('آزمایشگاه کدنویسی'), backgroundColor: const Color(0xFF1A1030), foregroundColor: Colors.white),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
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
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PackageLibraryScreen())), icon: const Icon(Icons.library_books), label: const Text('مرور کتابخانه‌ها')),
              OutlinedButton.icon(onPressed: _openSavedProject, icon: const Icon(Icons.folder_open), label: const Text('پروژه‌های من')),
              OutlinedButton.icon(onPressed: _saveProject, icon: const Icon(Icons.save), label: const Text('ذخیره پروژه')),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              const Expanded(child: Text('ویرایشگر کد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              IconButton(tooltip: 'کپی کد', onPressed: () => Clipboard.setData(ClipboardData(text: _code.text)), icon: const Icon(Icons.copy, color: purple)),
              IconButton(tooltip: 'پاک کردن', onPressed: () => setState(() => _code.clear()), icon: const Icon(Icons.delete_outline, color: Colors.white70)),
            ]),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF171522), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF49366C))),
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _code, minLines: 12, maxLines: 22, keyboardType: TextInputType.multiline,
                style: const TextStyle(color: Color(0xFFE8DFFF), fontFamily: 'monospace', fontSize: 13, height: 1.45),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'کد خود را اینجا بنویسید...', hintStyle: TextStyle(color: Colors.white38)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('ورودی برنامه (stdin)', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            TextField(
              controller: _stdin, minLines: 1, maxLines: 3, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'ورودی اختیاری برنامه', hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: const Color(0xFF211936), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 14),
            const Text('ترمینال دستورها', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextField(
                controller: _terminalCommand, style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: _language == 'python' ? 'pip install requests' : 'mvn dependency:get -Dartifact=...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12), filled: true, fillColor: const Color(0xFF211936),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _terminalAction(),
              )),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _installing ? null : _terminalAction, icon: _installing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow)),
            ]),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _running ? null : _run,
              icon: _running ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
              label: Text(_running ? 'در حال اجرا...' : 'اجرای کد در ترمینال'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6D4CE8), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 18),
            Row(children: [
              const Icon(Icons.terminal, color: purple), const SizedBox(width: 8),
              const Expanded(child: Text('ترمینال خروجی', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              TextButton(onPressed: () => setState(() => _output = ''), child: const Text('پاک کردن خروجی')),
            ]),
            Container(
              constraints: const BoxConstraints(minHeight: 130), width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF080B10), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF3B3150))),
              child: SelectableText(_output, style: const TextStyle(color: Color(0xFFB9F6CA), fontFamily: 'monospace', fontSize: 12, height: 1.5)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF211936), borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'اجرای کد در محیط ابری انجام می‌شود. نصب بسته‌های مجاز Python به سرویس Piston ارسال می‌شود؛ ممکن است ماندگار نباشد. نصب از میرور ایران و نصب واقعی وابستگی‌های Maven هنوز به Runner اختصاصی نیاز دارد.',
                style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 12),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}