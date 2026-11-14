import 'package:flutter/material.dart';
import '../services/backend_service.dart';

class OwnerPanelScreen extends StatefulWidget {
  const OwnerPanelScreen({super.key});
  @override
  State<OwnerPanelScreen> createState() => _OwnerPanelScreenState();
}

class _OwnerPanelScreenState extends State<OwnerPanelScreen> {
  final _name = TextEditingController();
  final _model = TextEditingController();
  final _baseUrl = TextEditingController();
  final _prompt = TextEditingController();
  final _rubika = TextEditingController();
  final _myket = TextEditingController();
  final _price = TextEditingController();
  final _duration = TextEditingController();
  final _announcement = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _allowed = false;
  List<Map<String, dynamic>> _assistants = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _conversations = [];

  Future<void> _loadPurchases() async {
    final rows = await BackendService.client
        .from('purchases')
        .select('id,user_id,plan_code,amount,currency,provider,provider_reference,status,created_at,verified_at')
        .order('created_at', ascending: false)
        .limit(500);
    _purchases = rows.map((row) => Map<String, dynamic>.from(row)).toList();
    if (mounted) setState(() {});
  }

  Future<void> _loadConversations() async {
    final rows = await BackendService.client
        .from('conversations')
        .select('id,user_id,title,created_at,updated_at')
        .order('updated_at', ascending: false)
        .limit(100);
    _conversations = rows.map((row) => Map<String, dynamic>.from(row)).toList();
    if (mounted) setState(() {});
  }

  Future<void> _showConversation(Map<String, dynamic> conversation) async {
    try {
      final rows = await BackendService.client
          .from('messages')
          .select('role,content,created_at')
          .eq('conversation_id', conversation['id'])
          .order('created_at')
          .limit(200);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(conversation['title']?.toString() ?? 'گفتگو'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: rows.length,
                itemBuilder: (_, index) {
                  final message = rows[index];
                  return ListTile(
                    dense: true,
                    title: Text(message['role'] == 'user' ? 'کاربر' : 'وارنیکس'),
                    subtitle: SelectableText(message['content']?.toString() ?? ''),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('بستن')),
            ],
          ),
        ),
      );
    } catch (e) {
      _notify('نمایش گفتگو ناموفق بود: $e');
    }
  }


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _allowed = await BackendService.isCurrentUserAdmin();
      if (!_allowed) return;
      final config = await BackendService.loadAppConfig();
      _name.text = config['app_name']?.toString() ?? 'Varnix AI';
      _model.text = config['default_model']?.toString() ?? 'openrouter/free';
      _baseUrl.text = config['api_base_url']?.toString() ?? 'https://openrouter.ai/api/v1';
      _prompt.text = config['system_prompt']?.toString() ?? '';
      _rubika.text = config['rubika_url']?.toString() ?? '';
      _myket.text = config['myket_url']?.toString() ?? '';
      _price.text = config['pro_price']?.toString() ?? '';
      _duration.text = (config['pro_duration_days'] ?? 30).toString();
      _announcement.text = config['announcement']?.toString() ?? '';
      await _loadAssistants();
      await _loadUsers();
      await _loadPurchases();
      await _loadConversations();
    } catch (e) {
      _notify('بارگذاری تنظیمات ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUsers() async {
    final rows = await BackendService.client
        .from('profiles')
        .select('id,email,display_name,role,plan_code,plan_expires_at')
        .order('created_at', ascending: false)
        .limit(100);
    _users = rows.map((row) => Map<String, dynamic>.from(row)).toList();
    if (mounted) setState(() {});
  }

  Future<void> _applyUserAction(Map<String, dynamic> user, String action) async {
    try {
      final params = <String, dynamic>{'target_user_id': user['id']};
      if (action == 'pro') {
        final days = int.tryParse(_duration.text.trim()) ?? 30;
        params['new_plan_code'] = 'pro';
        params['new_plan_expires_at'] = DateTime.now()
            .add(Duration(days: days))
            .toUtc()
            .toIso8601String();
      } else if (action == 'free') {
        params['new_plan_code'] = 'free';
      } else if (action == 'admin') {
        params['new_role'] = 'admin';
      } else if (action == 'user') {
        params['new_role'] = 'user';
      }
      await BackendService.client.rpc('admin_update_profile', params: params);
      await _loadUsers();
      _notify('اطلاعات کاربر به‌روزرسانی شد.');
    } catch (e) {
      _notify('تغییر حساب کاربر ناموفق بود: $e');
    }
  }

  Future<void> _loadAssistants() async {
    final rows = await BackendService.client
        .from('assistants')
        .select('id,name,description,icon,system_prompt,model,is_active,sort_order')
        .order('sort_order');
    _assistants = rows.map((row) => Map<String, dynamic>.from(row)).toList();
    if (mounted) setState(() {});
  }

  Future<void> _editAssistant([Map<String, dynamic>? assistant]) async {
    final name = TextEditingController(text: assistant?['name']?.toString() ?? '');
    final description = TextEditingController(text: assistant?['description']?.toString() ?? '');
    final icon = TextEditingController(text: assistant?['icon']?.toString() ?? '✨');
    final model = TextEditingController(text: assistant?['model']?.toString() ?? 'openrouter/free');
    final prompt = TextEditingController(text: assistant?['system_prompt']?.toString() ?? '');
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(assistant == null ? 'ساخت دستیار جدید' : 'ویرایش دستیار'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'نام دستیار')),
                TextField(controller: description, decoration: const InputDecoration(labelText: 'توضیحات')),
                TextField(controller: icon, decoration: const InputDecoration(labelText: 'ایموجی / آیکون')),
                TextField(controller: model, decoration: const InputDecoration(labelText: 'مدل (مثلاً openrouter/free)')),
                TextField(controller: prompt, minLines: 3, maxLines: 6,
                  decoration: const InputDecoration(labelText: 'دستورالعمل اختصاصی دستیار')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('لغو')),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty || prompt.text.trim().isEmpty || model.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, {
                  'name': name.text.trim(),
                  'description': description.text.trim(),
                  'icon': icon.text.trim().isEmpty ? '✨' : icon.text.trim(),
                  'model': model.text.trim(),
                  'system_prompt': prompt.text.trim(),
                });
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    icon.dispose();
    model.dispose();
    prompt.dispose();
    if (result == null) return;
    try {
      if (assistant == null) {
        await BackendService.client.from('assistants').insert(result);
      } else {
        await BackendService.client.from('assistants').update(result).eq('id', assistant['id']);
      }
      await _loadAssistants();
      _notify('دستیار ذخیره شد.');
    } catch (e) {
      _notify('ذخیره دستیار ناموفق بود: $e');
    }
  }

  Future<void> _toggleAssistant(Map<String, dynamic> assistant) async {
    try {
      await BackendService.client.from('assistants')
          .update({'is_active': !(assistant['is_active'] == true)})
          .eq('id', assistant['id']);
      await _loadAssistants();
    } catch (e) {
      _notify('تغییر وضعیت دستیار ناموفق بود: $e');
    }
  }

  Future<void> _deleteAssistant(Map<String, dynamic> assistant) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف دستیار'),
        content: Text('دستیار «${assistant['name']}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('لغو')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await BackendService.client.from('assistants').delete().eq('id', assistant['id']);
      await _loadAssistants();
      _notify('دستیار حذف شد.');
    } catch (e) {
      _notify('حذف دستیار ناموفق بود: $e');
    }
  }

  Future<void> _save() async {
    final days = int.tryParse(_duration.text.trim());
    if (days == null || days < 1) {
      _notify('مدت پلن باید عددی بزرگ‌تر از صفر باشد.');
      return;
    }
    if (!_baseUrl.text.trim().startsWith('https://')) {
      _notify('آدرس API باید با https شروع شود.');
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendService.client.from('app_config').update({
        'app_name': _name.text.trim(),
        'default_model': _model.text.trim(),
        'api_base_url': _baseUrl.text.trim(),
        'system_prompt': _prompt.text.trim(),
        'rubika_url': _rubika.text.trim(),
        'myket_url': _myket.text.trim(),
        'pro_price': _price.text.trim(),
        'pro_duration_days': days,
        'announcement': _announcement.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', true);
      if (mounted) {
        _notify('تنظیمات روی سرور ذخیره شد و برای همهٔ کاربران اعمال می‌شود.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _notify('ذخیره‌سازی ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _field(String label, TextEditingController controller, {int lines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: lines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFF252540),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('پنل مدیریت وارنیکس')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_allowed
                ? const Center(child: Text('دسترسی مدیر برای این حساب فعال نیست.'))
                : ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      const Text('تنظیمات عمومی',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      _field('نام برنامه', _name),
                      _field('مدل هوش مصنوعی', _model),
                      _field('آدرس API', _baseUrl),
                      _field('دستورالعمل اصلی هوش مصنوعی', _prompt, lines: 5),
                      _field('لینک کانال روبیکا', _rubika),
                      _field('لینک مایکت', _myket),
                      const Divider(height: 28),
                      const Text('پلن حرفه‌ای',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      _field('قیمت پلن', _price),
                      _field('مدت پلن (روز)', _duration, keyboard: TextInputType.number),
                      _field('اعلان عمومی برای کاربران', _announcement, lines: 3),
                      const Divider(height: 30),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('مدیریت کاربران و پلن‌ها',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            tooltip: 'بارگذاری دوباره کاربران',
                            onPressed: _loadUsers,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      if (_users.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('کاربری ثبت‌نام نکرده است.',
                            style: TextStyle(color: Colors.white60)),
                        ),
                      ..._users.map((user) => Card(
                        color: const Color(0xFF211A35),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text((user['display_name']?.toString().isNotEmpty == true)
                                ? user['display_name'].toString().substring(0, 1)
                                : '؟'),
                          ),
                          title: Text(user['display_name']?.toString().isNotEmpty == true
                              ? user['display_name'].toString()
                              : (user['email']?.toString() ?? 'کاربر')),
                          subtitle: Text(
                            '${user['email'] ?? ''} • ${user['plan_code'] ?? 'free'} • ${user['role'] ?? 'user'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) => _applyUserAction(user, value),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'pro', child: Text('فعال‌سازی پلن حرفه‌ای')),
                              PopupMenuItem(value: 'free', child: Text('بازگشت به پلن رایگان')),
                              PopupMenuItem(value: 'admin', child: Text('اعطای دسترسی مدیر')),
                              PopupMenuItem(value: 'user', child: Text('حذف دسترسی مدیر')),
                            ],
                          ),
                        ),
                      )),

                      const Divider(height: 30),
                      Row(
                        children: [
                          const Expanded(child: Text('مدیریت خریدها',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          IconButton(onPressed: _loadPurchases, icon: const Icon(Icons.refresh)),
                        ],
                      ),
                      if (_purchases.isEmpty)
                        const Text('هنوز خریدی ثبت نشده است.'),
                      ..._purchases.map((purchase) => Card(
                        child: ListTile(
                          title: Text('${purchase['plan_code']} • ${purchase['amount']} ${purchase['currency']}'),
                          subtitle: Text('کاربر: ${purchase['user_id']}\nوضعیت: ${purchase['status']} • ${purchase['provider']}',
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                          isThreeLine: true,
                        ),
                      )),
                      const Divider(height: 30),
                      Row(
                        children: [
                          const Expanded(child: Text('گفتگوهای کاربران',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          IconButton(onPressed: _loadConversations, icon: const Icon(Icons.refresh)),
                        ],
                      ),
                      if (_conversations.isEmpty)
                        const Text('گفتگویی برای نمایش وجود ندارد.'),
                      ..._conversations.map((conversation) => Card(
                        child: ListTile(
                          title: Text(conversation['title']?.toString() ?? 'گفتگوی جدید'),
                          subtitle: Text('شناسه کاربر: ${conversation['user_id']}'),
                          trailing: IconButton(
                            tooltip: 'مشاهده پیام‌ها',
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: () => _showConversation(conversation),
                          ),
                        ),
                      )),

                      const Divider(height: 30),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('مدیریت دستیارها',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            tooltip: 'افزودن دستیار',
                            onPressed: () => _editAssistant(),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      if (_assistants.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('هنوز دستیار اختصاصی نساخته‌اید.',
                            style: TextStyle(color: Colors.white60)),
                        ),
                      ..._assistants.map((assistant) => Card(
                        color: const Color(0xFF211A35),
                        child: ListTile(
                          leading: Text(assistant['icon']?.toString() ?? '✨',
                            style: const TextStyle(fontSize: 24)),
                          title: Text(assistant['name']?.toString() ?? 'دستیار'),
                          subtitle: Text(
                            '${assistant['model']} • ${assistant['is_active'] == true ? 'فعال' : 'غیرفعال'}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _editAssistant(assistant);
                              if (value == 'toggle') _toggleAssistant(assistant);
                              if (value == 'delete') _deleteAssistant(assistant);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                              PopupMenuItem(value: 'toggle',
                                child: Text(assistant['is_active'] == true ? 'غیرفعال‌کردن' : 'فعال‌کردن')),
                              const PopupMenuItem(value: 'delete', child: Text('حذف')),
                            ],
                          ),
                        ),
                      )),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const CircularProgressIndicator()
                              : const Text('ذخیره تنظیمات روی سرور'),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _name, _model, _baseUrl, _prompt, _rubika, _myket, _price, _duration, _announcement,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
