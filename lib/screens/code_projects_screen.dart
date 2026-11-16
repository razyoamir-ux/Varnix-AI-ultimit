import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CodeProjectsScreen extends StatefulWidget {
  const CodeProjectsScreen({super.key});
  @override
  State<CodeProjectsScreen> createState() => _CodeProjectsScreenState();
}

class _CodeProjectsScreenState extends State<CodeProjectsScreen> {
  static const _key = 'varnix_code_projects_v1';
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        _projects = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        _projects = [];
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_projects));
  }

  Future<void> _newProject() async {
    final name = TextEditingController();
    final code = TextEditingController(text: 'print("Hello Varnix")');
    String language = 'python';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
        title: const Text('پروژه جدید'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'نام پروژه')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: language,
            items: const [
              DropdownMenuItem(value: 'python', child: Text('Python')),
              DropdownMenuItem(value: 'java', child: Text('Java')),
            ],
            onChanged: (v) => setDialog(() {
              language = v ?? 'python';
              code.text = language == 'python'
                ? 'print("Hello Varnix")'
                : 'public class Main { public static void main(String[] args) { System.out.println("Hello Varnix"); } }';
            }),
            decoration: const InputDecoration(labelText: 'زبان'),
          ),
          const SizedBox(height: 10),
          TextField(controller: code, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'کد')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(ctx, {
            'name': name.text.trim().isEmpty ? 'پروژه بدون نام' : name.text.trim(),
            'language': language,
            'code': code.text,
          }), child: const Text('ذخیره')),
        ],
      )),
    );
    name.dispose();
    code.dispose();
    if (result == null) return;
    _projects.insert(0, {
      ...result,
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'updated': DateTime.now().toIso8601String(),
    });
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _delete(String id) async {
    _projects.removeWhere((p) => p['id'] == id);
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _copy(Map<String, dynamic> p) async {
    await Clipboard.setData(ClipboardData(text: p['code']?.toString() ?? ''));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کد پروژه کپی شد.')));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(title: const Text('پروژه‌های من'), backgroundColor: const Color(0xFF1A1030), foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newProject,
        backgroundColor: const Color(0xFF6D4CE8),
        icon: const Icon(Icons.add),
        label: const Text('پروژه جدید'),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _projects.isEmpty
          ? const Center(child: Text('هنوز پروژه‌ای ذخیره نکردی.\nاولین پروژه‌ات را بساز!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.7)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: _projects.length,
              itemBuilder: (context, i) {
                final p = _projects[i];
                return Card(
                  color: const Color(0xFF211936),
                  child: ListTile(
                    leading: Icon(p['language'] == 'java' ? Icons.coffee : Icons.code, color: const Color(0xFFA78BFA)),
                    title: Text(p['name']?.toString() ?? 'پروژه', style: const TextStyle(color: Colors.white)),
                    subtitle: Text((p['language'] ?? 'python').toString().toUpperCase(), style: const TextStyle(color: Colors.white54)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'copy') _copy(p);
                        if (v == 'delete') _delete(p['id'].toString());
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'copy', child: Text('کپی کد')),
                        PopupMenuItem(value: 'delete', child: Text('حذف پروژه')),
                      ],
                    ),
                    onTap: () => Navigator.pop(context, p),
                  ),
                );
              },
            ),
    ),
  );
}
