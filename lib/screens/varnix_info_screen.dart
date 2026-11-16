import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class VarnixInfoScreen extends StatelessWidget {
  const VarnixInfoScreen({super.key, required this.section});
  final String section;
  static const bg = Color(0xFF0F0F1A);
  static const card = Color(0xFF211936);
  static const purple = Color(0xFFA78BFA);

  Future<List<Map<String, dynamic>>> load() async {
    final db = Supabase.instance.client;
    if (section == 'updates') {
      final rows = await db.from('app_releases').select().eq('is_published', true).order('published_at', ascending: false).limit(30);
      return List<Map<String, dynamic>>.from(rows);
    }
    if (section == 'apps') {
      final rows = await db.from('other_apps').select().eq('is_active', true).order('sort_order');
      return List<Map<String, dynamic>>.from(rows);
    }
    final rows = await db.from('content_documents').select().eq('slug', section).eq('is_published', true).limit(1);
    return List<Map<String, dynamic>>.from(rows);
  }

  String get title => switch (section) {
    'about' => 'درباره وارنیکس',
    'terms' => 'شرایط و قوانین',
    'privacy' => 'حریم خصوصی',
    'apps' => 'سایر برنامه‌های ما',
    _ => 'به‌روزرسانی‌ها',
  };

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: Text(title), backgroundColor: bg),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('دریافت اطلاعات ممکن نشد. اتصال اینترنت و دیتابیس را بررسی کن.', style: TextStyle(color: Colors.white70)));
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) return const Center(child: Text('محتوایی برای نمایش وجود ندارد.', style: TextStyle(color: Colors.white70)));
          if (section == 'apps') {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: rows.map((row) {
                final published = row['status'] == 'published';
                final storeUrl = (row['store_url'] ?? '').toString();
                return Card(
                  color: card,
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: purple, child: Icon(Icons.apps, color: Colors.white)),
                    title: Text((row['name'] ?? '').toString(), style: const TextStyle(color: Colors.white)),
                    subtitle: Text((row['description'] ?? '').toString() + (published ? '\nمنتشر شده' : '\nبه‌زودی'), style: const TextStyle(color: Colors.white70)),
                    trailing: published && storeUrl.isNotEmpty ? IconButton(
                      icon: const Icon(Icons.open_in_new, color: purple),
                      onPressed: () => _openUrl(storeUrl),
                    ) : null,
                  ),
                );
              }).toList(),
            );
          }
          if (section == 'updates') {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: rows.map((row) => Card(
                color: card,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('نسخه ' + (row['version'] ?? '').toString() + ' • ' + (row['title'] ?? '').toString(), style: const TextStyle(color: purple, fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 10),
                    Text((row['notes'] ?? '').toString(), style: const TextStyle(color: Colors.white, height: 1.8)),
                    if (row['is_mandatory'] == true) const Text('این به‌روزرسانی ضروری است.', style: TextStyle(color: Colors.orangeAccent)),
                    if ((row['download_url'] ?? '').toString().isNotEmpty) TextButton.icon(
                      onPressed: () => _openUrl(row['download_url'].toString()),
                      icon: const Icon(Icons.download),
                      label: const Text('دریافت نسخه جدید'),
                    ),
                  ]),
                ),
              )).toList(),
            );
          }
          final document = rows.first;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text((document['title'] ?? title).toString(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('نسخه ' + (document['version'] ?? '1.0').toString() + ' • آخرین ویرایش: ' + (document['updated_at'] ?? '—').toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const Divider(color: Colors.white24, height: 28),
              SelectableText((document['body'] ?? '').toString(), style: const TextStyle(color: Colors.white, height: 1.9, fontSize: 15)),
            ],
          );
        },
      ),
    ),
  );
}
