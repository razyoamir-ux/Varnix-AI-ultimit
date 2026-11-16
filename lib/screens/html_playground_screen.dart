import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HtmlPlaygroundScreen extends StatefulWidget {
  const HtmlPlaygroundScreen({super.key});
  @override
  State<HtmlPlaygroundScreen> createState() => _HtmlPlaygroundScreenState();
}

class _HtmlPlaygroundScreenState extends State<HtmlPlaygroundScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final WebViewController _preview;
  final _html = TextEditingController(text: '<main class="card">\n  <h1>سلام وارنیکس!</h1>\n  <p>اولین صفحه وب من 🚀</p>\n  <button onclick="sayHello()">کلیک کن</button>\n</main>');
  final _css = TextEditingController(text: 'body {\n  font-family: sans-serif;\n  background: #111827;\n  color: white;\n  text-align: center;\n  padding: 40px 16px;\n}\n.card {\n  max-width: 420px;\n  margin: 40px auto;\n  padding: 28px;\n  border-radius: 20px;\n  background: #312e81;\n}\nbutton {\n  padding: 12px 22px;\n  border: 0;\n  border-radius: 10px;\n  cursor: pointer;\n}');
  final _js = TextEditingController(text: 'function sayHello() {\n  alert("سلام! کدت درست اجرا شد 🎉");\n}');
  bool _loading = false;
  String _status = 'برای دیدن نتیجه، روی «اجرای پیش‌نمایش» بزن.';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _preview = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF));
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _html.text = prefs.getString('varnix_html_draft') ?? _html.text;
      _css.text = prefs.getString('varnix_css_draft') ?? _css.text;
      _js.text = prefs.getString('varnix_js_draft') ?? _js.text;
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('varnix_html_draft', _html.text);
    await prefs.setString('varnix_css_draft', _css.text);
    await prefs.setString('varnix_js_draft', _js.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پروژه HTML روی همین دستگاه ذخیره شد.')));
  }

  String _buildDocument() {
    return '<!doctype html><html lang="fa"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><style>' +
        _css.text +
        '</style></head><body>' +
        _html.text +
        '<script>try {' +
        _js.text +
        '} catch (error) { document.body.insertAdjacentHTML("beforeend", "<pre></pre>"); document.querySelector("pre").textContent = error.toString(); }</script></body></html>';
  }

  Future<void> _runPreview() async {
    setState(() { _loading = true; _status = 'در حال ساخت پیش‌نمایش...'; });
    try {
      await _preview.loadHtmlString(_buildDocument());
      if (!mounted) return;
      setState(() => _status = 'پیش‌نمایش به‌روزرسانی شد.');
      _tabs.animateTo(3);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'خطا در نمایش صفحه: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadExample() {
    setState(() {
      _html.text = '<section class="profile">\n  <div class="avatar">V</div>\n  <h1>وارنیکس وب</h1>\n  <p>این یک کارت پروفایل ساخته‌شده با HTML و CSS است.</p>\n  <button onclick="changeTitle()">تغییر عنوان</button>\n</section>';
      _css.text = 'body { margin: 0; padding: 32px 16px; background: #0f172a; color: white; font-family: sans-serif; text-align: center; }\n.profile { max-width: 360px; margin: 20px auto; padding: 28px; border-radius: 24px; background: linear-gradient(135deg,#6d28d9,#2563eb); }\n.avatar { width: 76px; height: 76px; margin: auto; border-radius: 50%; display: grid; place-items: center; background: white; color: #6d28d9; font-size: 38px; font-weight: bold; }\nbutton { border: 0; border-radius: 12px; padding: 12px 18px; font-weight: bold; }';
      _js.text = 'function changeTitle() { document.querySelector("h1").textContent = "عالی پیش می‌ری!"; }';
      _status = 'نمونه آماده بارگذاری شد؛ پیش‌نمایش را اجرا کن.';
    });
  }

  TextField _editor(TextEditingController controller, String hint) => TextField(
    controller: controller, expands: true, minLines: null, maxLines: null,
    keyboardType: TextInputType.multiline, textAlign: TextAlign.left,
    textDirection: TextDirection.ltr, autocorrect: false, enableSuggestions: false,
    style: const TextStyle(color: Color(0xFFE8DFFF), fontFamily: 'monospace', fontSize: 13, height: 1.5),
    decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white38), border: InputBorder.none, contentPadding: const EdgeInsets.all(14)),
  );

  @override
  void dispose() {
    _tabs.dispose(); _html.dispose(); _css.dispose(); _js.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text('آزمایشگاه HTML'),
        backgroundColor: const Color(0xFF1A1030),
        foregroundColor: Colors.white,
        actions: [IconButton(tooltip: 'ذخیره پروژه', onPressed: _saveDraft, icon: const Icon(Icons.save_outlined))],
        bottom: TabBar(controller: _tabs, isScrollable: true, tabs: const [
          Tab(text: 'HTML', icon: Icon(Icons.code)),
          Tab(text: 'CSS', icon: Icon(Icons.palette_outlined)),
          Tab(text: 'JavaScript', icon: Icon(Icons.javascript)),
          Tab(text: 'پیش‌نمایش', icon: Icon(Icons.web)),
        ]),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: _loading ? null : _runPreview,
              icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
              label: const Text('اجرای پیش‌نمایش'),
            ),
            OutlinedButton.icon(onPressed: _loadExample, icon: const Icon(Icons.lightbulb_outline), label: const Text('نمونه آماده')),
            OutlinedButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: _buildDocument())), icon: const Icon(Icons.copy), label: const Text('کپی HTML نهایی')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Align(alignment: Alignment.centerRight, child: Text(_status, style: const TextStyle(color: Colors.white60, fontSize: 12))),
        ),
        Expanded(child: TabBarView(controller: _tabs, children: [
          Container(margin: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF171522), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF49366C))), child: _editor(_html, 'کد HTML را اینجا بنویس...')),
          Container(margin: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF171522), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF49366C))), child: _editor(_css, 'استایل‌های CSS را اینجا بنویس...')),
          Container(margin: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF171522), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF49366C))), child: _editor(_js, 'کد JavaScript را اینجا بنویس...')),
          Container(margin: const EdgeInsets.all(10), clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: WebViewWidget(controller: _preview)),
        ])),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Text('کدها داخل پیش‌نمایش محلی برنامه اجرا می‌شوند؛ برای ذخیره دائمی، دکمه ذخیره را بزن.', style: TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
        ),
      ]),
    ),
  );
}
