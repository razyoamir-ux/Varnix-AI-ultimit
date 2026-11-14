import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyEditorScreen extends StatefulWidget {
  const StudyEditorScreen({super.key});
  @override
  State<StudyEditorScreen> createState() => _StudyEditorScreenState();
}
class _StudyEditorScreenState extends State<StudyEditorScreen> {
  final title = TextEditingController(text: 'یادداشت جدید');
  final body = TextEditingController();
  double fontSize = 18, lineHeight = 1.7;
  String font = 'پیش‌فرض', paper = 'سفید';
  bool bold = false, bullets = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      fontSize = p.getDouble('study_size') ?? 18;
      lineHeight = p.getDouble('study_line') ?? 1.7;
      font = p.getString('study_font') ?? 'پیش‌فرض';
      paper = p.getString('study_paper') ?? 'سفید';
      body.text = p.getString('study_draft') ?? '';
      title.text = p.getString('study_title') ?? 'یادداشت جدید';
    });
  }
  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('study_title', title.text); await p.setString('study_draft', body.text);
    await p.setDouble('study_size', fontSize); await p.setDouble('study_line', lineHeight);
    await p.setString('study_font', font); await p.setString('study_paper', paper);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('یادداشت روی همین دستگاه ذخیره شد.')));
  }
  @override
  Widget build(BuildContext context) {
    final bg = paper == 'کرم' ? const Color(0xFFFFF2D8) : paper == 'سبز' ? const Color(0xFFE5F3E6) : Colors.white;
    final fg = paper == 'سفید' || paper == 'کرم' || paper == 'سبز' ? Colors.black87 : Colors.white;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('دفتر درس و یادداشت'), actions: [
        IconButton(onPressed: _save, icon: const Icon(Icons.save_outlined), tooltip: 'ذخیره'),
        IconButton(onPressed: () => setState(() { body.clear(); }), icon: const Icon(Icons.delete_outline), tooltip: 'پاک‌کردن متن'),
      ]),
      body: Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          IconButton(onPressed: () => setState(() => bold = !bold), icon: Icon(Icons.format_bold, color: bold ? Colors.deepPurpleAccent : null)),
          IconButton(onPressed: () => setState(() { body.text = '• ${body.text}'; body.selection = TextSelection.collapsed(offset: body.text.length); }), icon: const Icon(Icons.format_list_bulleted)),
          IconButton(onPressed: () => setState(() { body.text += '\n────────────\n'; }), icon: const Icon(Icons.horizontal_rule)),
          IconButton(onPressed: () => setState(() => fontSize = (fontSize - 1).clamp(12, 32)), icon: const Icon(Icons.text_decrease)),
          IconButton(onPressed: () => setState(() => fontSize = (fontSize + 1).clamp(12, 32)), icon: const Icon(Icons.text_increase)),
          PopupMenuButton<String>(icon: const Icon(Icons.font_download), onSelected: (v) => setState(() => font = v), itemBuilder: (_) => ['پیش‌فرض','Serif','Monospace'].map((v) => PopupMenuItem(value: v, child: Text(v))).toList()),
          PopupMenuButton<String>(icon: const Icon(Icons.palette_outlined), onSelected: (v) => setState(() => paper = v), itemBuilder: (_) => ['سفید','کرم','سبز','تیره'].map((v) => PopupMenuItem(value: v, child: Text(v))).toList()),
          IconButton(onPressed: () => setState(() => lineHeight = (lineHeight + .1).clamp(1.2, 2.5)), icon: const Icon(Icons.format_line_spacing)),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: TextField(controller: title, decoration: const InputDecoration(hintText: 'عنوان یادداشت', border: InputBorder.none), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        Expanded(child: Container(color: bg, padding: const EdgeInsets.all(16), child: TextField(
          controller: body, expands: true, maxLines: null, minLines: null, textAlignVertical: TextAlignVertical.top,
          style: TextStyle(color: fg, fontSize: fontSize, height: lineHeight, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontFamily: font == 'Serif' ? 'serif' : font == 'Monospace' ? 'monospace' : null),
          decoration: const InputDecoration(border: InputBorder.none, hintText: 'اینجا شروع به نوشتن درس یا یادداشتت کن...'),
        ))),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          const Expanded(child: Text('ذخیره محلی روی همین دستگاه', style: TextStyle(color: Colors.white60, fontSize: 12))),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('ذخیره')),
        ]))),
      ]),
    ));
  }
  @override
  void dispose() { title.dispose(); body.dispose(); super.dispose(); }
}
