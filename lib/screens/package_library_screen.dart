import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PackageLibraryScreen extends StatefulWidget {
  const PackageLibraryScreen({super.key});
  @override
  State<PackageLibraryScreen> createState() => _PackageLibraryScreenState();
}

class _PackageLibraryScreenState extends State<PackageLibraryScreen> {
  String _language = 'python';
  String _query = '';
  bool _busy = false;
  String _status = 'کتابخانه را جست‌وجو کن و بسته موردنیازت را انتخاب کن.';

  static const _python = <Map<String, String>>[
    {'name': 'requests', 'description': 'ارسال درخواست‌های HTTP', 'category': 'شبکه'},
    {'name': 'numpy', 'description': 'محاسبات عددی و آرایه‌ها', 'category': 'علمی'},
    {'name': 'pandas', 'description': 'تحلیل و پردازش داده', 'category': 'داده'},
    {'name': 'matplotlib', 'description': 'رسم نمودار و تصویرسازی داده', 'category': 'علمی'},
    {'name': 'pillow', 'description': 'پردازش تصویر', 'category': 'تصویر'},
    {'name': 'rich', 'description': 'خروجی رنگی و زیباتر ترمینال', 'category': 'ابزار'},
    {'name': 'sympy', 'description': 'محاسبات نمادین ریاضی', 'category': 'علمی'},
    {'name': 'beautifulsoup4', 'description': 'تجزیه HTML و XML', 'category': 'وب'},
  ];

  static const _java = <Map<String, String>>[
    {'name': 'com.google.guava:guava:33.0.0-jre', 'description': 'ابزارهای کاربردی Java', 'category': 'ابزار'},
    {'name': 'com.google.code.gson:gson:2.11.0', 'description': 'تبدیل JSON و Java', 'category': 'داده'},
    {'name': 'org.apache.commons:commons-lang3:3.14.0', 'description': 'ابزارهای تکمیلی زبان', 'category': 'ابزار'},
    {'name': 'org.junit.jupiter:junit-jupiter:5.10.2', 'description': 'تست واحد برنامه‌ها', 'category': 'تست'},
  ];

  Future<void> _install(String name) async {
    if (_busy) return;
    final command = _language == 'python'
        ? 'pip install $name'
        : 'mvn dependency:get -Dartifact=$name';
    await Clipboard.setData(ClipboardData(text: command));
    if (!mounted) return;
    setState(() => _status = _language == 'python'
        ? 'دستور «$command» کپی شد. محیط اجرای ابری وارنیکس موقتی است و نصب بسته را بین اجراها نگه نمی‌دارد؛ این دستور را در محیط Python خودت اجرا کن.'
        : 'دستور Maven کپی شد. نصب مستقیم وابستگی Java در Runner فعلی فعال نیست.');
  }

  @override
  Widget build(BuildContext context) {
    final source = _language == 'python' ? _python : _java;
    final filtered = source.where((p) =>
      p['name']!.toLowerCase().contains(_query.toLowerCase()) ||
      p['description']!.toLowerCase().contains(_query.toLowerCase())).toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(title: const Text('مرور کتابخانه‌ها'), backgroundColor: const Color(0xFF1A1030), foregroundColor: Colors.white),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'python', label: Text('Python'), icon: Icon(Icons.code)),
              ButtonSegment(value: 'java', label: Text('Java / Maven'), icon: Icon(Icons.coffee)),
            ],
            selected: {_language},
            onSelectionChanged: (v) => setState(() { _language = v.first; _query = ''; }),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Color(0xFFA78BFA)),
              hintText: 'جست‌وجوی نام کتابخانه...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: const Color(0xFF211936),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF211936), borderRadius: BorderRadius.circular(12)),
            child: Text(_status, style: const TextStyle(color: Colors.white70, height: 1.5)),
          ),
          const SizedBox(height: 12),
          ...filtered.map((p) => Card(
            color: const Color(0xFF211936),
            child: ListTile(
              title: Text(p['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('${p['description']} • ${p['category']}', style: const TextStyle(color: Colors.white60)),
              trailing: _busy && _language == 'python'
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    tooltip: 'کپی دستور نصب',
                    icon: const Icon(Icons.copy, color: Color(0xFFA78BFA)),
                    onPressed: _busy ? null : () => _install(p['name']!),
                  ),
            ),
          )),
          if (filtered.isEmpty) const Padding(
            padding: EdgeInsets.all(24),
            child: Text('کتابخانه‌ای با این نام پیدا نشد.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
          ),
          const SizedBox(height: 8),
          const Text(
            'نکته: این صفحه فهرست بسته‌ها و دستور نصب را آماده می‌کند. نصب پایدار بسته‌ها در محیط ابری و Maven هنوز به Runner اختصاصی نیاز دارد؛ بنابراین هیچ نصب موفقی به‌صورت کاذب گزارش نمی‌شود.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
          ),
        ]),
      ),
    );
  }
}
