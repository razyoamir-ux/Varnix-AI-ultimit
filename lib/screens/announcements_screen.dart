import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late Future<Map<String, dynamic>?> _announcement;

  @override
  void initState() {
    super.initState();
    _announcement = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    return Supabase.instance.client
        .from('app_config')
        .select('announcement, updated_at')
        .eq('id', true)
        .maybeSingle();
  }

  void _refresh() {
    setState(() => _announcement = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          title: const Text('اعلان‌های وارنیکس'),
          backgroundColor: const Color(0xFF1A1030),
          actions: [
            IconButton(
              tooltip: 'بروزرسانی',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _announcement,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _message(
                Icons.cloud_off_outlined,
                'دریافت اعلان‌ها ممکن نشد',
                'اتصال اینترنت را بررسی کن و دوباره تلاش کن.',
                retry: _refresh,
              );
            }
            final row = snapshot.data;
            final message = (row?['announcement'] ?? '').toString().trim();
            if (message.isEmpty) {
              return _message(
                Icons.notifications_none,
                'فعلاً اطلاعیه‌ای وجود ندارد',
                'اگر مدیر وارنیکس اطلاعیه‌ای منتشر کند، آن را همین‌جا می‌بینی.',
              );
            }
            final updated = DateTime.tryParse((row?['updated_at'] ?? '').toString())?.toLocal();
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF211936),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(.55)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.campaign_outlined, color: Color(0xFFA78BFA)),
                          SizedBox(width: 8),
                          Text(
                            'اطلاعیه رسمی',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                        ],
                      ),
                      if (updated != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'آخرین بروزرسانی: ${updated.year}/${updated.month.toString().padLeft(2, '0')}/${updated.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                      const Divider(color: Colors.white24, height: 26),
                      SelectableText(
                        message,
                        style: const TextStyle(color: Colors.white, height: 1.8, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'این بخش فقط اطلاعیه‌های داخل اپلیکیشن را نمایش می‌دهد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _message(IconData icon, String title, String detail, {VoidCallback? retry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFA78BFA), size: 48),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.6)),
            if (retry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: retry, child: const Text('تلاش دوباره')),
            ],
          ],
        ),
      ),
    );
  }
}
