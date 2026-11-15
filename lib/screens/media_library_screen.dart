import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/backend_service.dart';

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key});
  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen> {
  static const _bucket = 'varnix-media';
  bool _loading = true;
  bool _uploading = false;
  List<FileObject> _files = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  String get _folder => BackendService.currentUser!.id;

  Future<void> _refresh() async {
    try {
      final files = await BackendService.client.storage.from(_bucket).list(
        path: _folder,
        searchOptions: const SearchOptions(limit: 100, sortBy: SortBy(column: 'created_at', order: 'desc')),
      );
      if (mounted) setState(() { _files = files.where((f) => f.name != '.emptyFolderPlaceholder').toList(); _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _message('بارگذاری کتابخانه انجام نشد: $e');
    }
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) throw Exception('خواندن فایل ${file.name} ممکن نشد.');
        if (bytes.length > 50 * 1024 * 1024) throw Exception('حجم هر فایل باید کمتر از ۵۰ مگابایت باشد.');
        final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final path = '$_folder/${DateTime.now().microsecondsSinceEpoch}_$safeName';
        await BackendService.client.storage.from(_bucket).uploadBinary(
          path, bytes,
          fileOptions: const FileOptions(contentType: 'application/octet-stream', upsert: false),
        );
      }
      _message('فایل‌ها با موفقیت به کتابخانه اضافه شدند. ✅');
      await _refresh();
    } catch (e) {
      _message('آپلود ناموفق بود: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openFile(FileObject file) async {
    try {
      final url = await BackendService.client.storage.from(_bucket).createSignedUrl('$_folder/${file.name}', 300);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SelectableText('لینک امن فایل (اعتبار ۵ دقیقه):\n$url'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))],
      ));
    } catch (e) { _message('بازکردن فایل انجام نشد: $e'); }
  }

  Future<void> _delete(FileObject file) async {
    try {
      await BackendService.client.storage.from(_bucket).remove(['$_folder/${file.name}']);
      await _refresh();
      _message('فایل حذف شد.');
    } catch (e) { _message('حذف فایل ناموفق بود: $e'); }
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  IconData _icon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg','jpeg','png','webp','gif'].contains(ext)) return Icons.image_outlined;
    if (['mp4','webm','mov','m4v'].contains(ext)) return Icons.video_library_outlined;
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('رسانه‌ها و فایل‌های من'), actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _pickAndUpload,
        icon: _uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
        label: Text(_uploading ? 'در حال آپلود...' : 'افزودن فایل'),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) :
        _files.isEmpty ? Center(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.perm_media_outlined, size: 58, color: Color(0xFFA78BFA)),
            SizedBox(height: 12),
            Text('کتابخانه‌ات هنوز خالیه 📂', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('عکس‌ها، ویدئوها و فایل‌های موردنیازت رو اینجا نگه دار.', textAlign: TextAlign.center),
          ]),
        )) : RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: _files.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final file = _files[index];
              return ListTile(
                leading: Icon(_icon(file.name), color: const Color(0xFFA78BFA), size: 28),
                title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(file.createdAt ?? 'فایل ذخیره‌شده'),
                onTap: () => _openFile(file),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(file)),
              );
            },
          ),
        ),
    ),
  );
}
