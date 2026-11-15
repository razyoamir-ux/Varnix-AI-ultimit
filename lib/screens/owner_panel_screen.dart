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
  final _basePrice = TextEditingController();
  final _freeMessages = TextEditingController();
  final _freeImages = TextEditingController();
  final _freeFiles = TextEditingController();
  final _freeVideos = TextEditingController();
  final _freeEconomicVoice = TextEditingController();
  final _freeAdvancedVoice = TextEditingController();
  final _proImages = TextEditingController();
  final _proVideos = TextEditingController();
  final _bannerUnit = TextEditingController();
  final _interstitialUnit = TextEditingController();
  final _rewardedUnit = TextEditingController();
  final _announcement = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _allowed = false;
  bool _paymentEnabled = false;
  bool _adsEnabled = true;
  bool _bannerEnabled = true;
  bool _interstitialEnabled = false;
  bool _rewardedEnabled = false;
  List<Map<String, dynamic>> _assistants = [];
  List<Map<String, dynamic>> _models = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _conversations = [];
  Map<String, dynamic> _dashboardStats = {};

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
      await _loadDashboardStats();
      final config = await BackendService.loadAppConfig();
      _name.text = config['app_name']?.toString() ?? 'Varnix AI';
      _model.text = config['default_model']?.toString() ?? 'openrouter/free';
      _baseUrl.text = config['api_base_url']?.toString() ?? 'https://openrouter.ai/api/v1';
      _prompt.text = config['system_prompt']?.toString() ?? '';
      _rubika.text = config['rubika_url']?.toString() ?? '';
      _myket.text = config['myket_url']?.toString() ?? '';
      _price.text = config['pro_price']?.toString() ?? '136000';
      _basePrice.text = (config['pro_base_price'] ?? 120000).toString();
      _duration.text = (config['pro_duration_days'] ?? 30).toString();
      _freeMessages.text = (config['free_daily_message_limit'] ?? 30).toString();
      _freeImages.text = (config['free_daily_image_limit'] ?? 3).toString();
      _freeFiles.text = (config['free_daily_file_limit'] ?? 2).toString();
      _freeVideos.text = (config['free_daily_video_limit'] ?? 1).toString();
      _freeEconomicVoice.text = (config['free_voice_economic_minutes'] ?? 5).toString();
      _freeAdvancedVoice.text = (config['free_voice_advanced_minutes'] ?? 2).toString();
      _proImages.text = (config['pro_daily_image_generation_limit'] ?? 10).toString();
      _proVideos.text = (config['pro_daily_video_generation_limit'] ?? 2).toString();
      _bannerUnit.text = config['ad_banner_unit_id']?.toString() ?? '';
      _interstitialUnit.text = config['ad_interstitial_unit_id']?.toString() ?? '';
      _rewardedUnit.text = config['ad_rewarded_unit_id']?.toString() ?? '';
      _adsEnabled = config['ads_enabled'] != false;
      _bannerEnabled = config['ad_banner_enabled'] == true;
      _interstitialEnabled = config['ad_interstitial_enabled'] == true;
      _rewardedEnabled = config['ad_rewarded_enabled'] == true;
      _announcement.text = config['announcement']?.toString() ?? '';
      _paymentEnabled = config['payment_enabled'] == true;
      await _loadModels();
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

  Future<void> _loadDashboardStats() async {
    try {
      final result = await BackendService.client.rpc('admin_dashboard_summary');
      if (result is Map) {
        _dashboardStats = Map<String, dynamic>.from(result);
      }
      if (mounted) setState(() {});
    } catch (e) {
      _notify('بارگذاری آمار پنل انجام نشد: $e');
    }
  }

  String _statValue(String key) => (_dashboardStats[key] ?? 0).toString();

  Widget _statCard(String title, String value, IconData icon) {
    return Card(
      color: const Color(0xFF211A35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
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
        params['new_plan_code'] = action;
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
        params['new_plan_code'] = 'free';
      }
      await BackendService.client.rpc('admin_update_profile', params: params);
      await _loadUsers();
      _notify('اطلاعات کاربر به‌روزرسانی شد.');
    } catch (e) {
      _notify('تغییر حساب کاربر ناموفق بود: $e');
    }
  }

  Future<void> _loadModels() async {
    final rows = await BackendService.client
        .from('ai_models')
        .select('id,provider,model_id,display_name,description,is_active,sort_order')
        .order('sort_order')
        .order('display_name');
    _models = rows.map((row) => Map<String, dynamic>.from(row)).toList();
    if (mounted) setState(() {});
  }

  Future<void> _editAiModel([Map<String, dynamic>? model]) async {
    final id = TextEditingController(text: model?['model_id']?.toString() ?? '');
    final name = TextEditingController(text: model?['display_name']?.toString() ?? '');
    final description = TextEditingController(text: model?['description']?.toString() ?? '');
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(model == null ? 'افزودن مدل هوش مصنوعی' : 'ویرایش مدل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: id, decoration: const InputDecoration(
                  labelText: 'شناسه مدل OpenRouter',
                  hintText: 'مثلاً openai/gpt-4.1-mini',
                )),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'نام نمایشی')),
                TextField(controller: description, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('لغو')),
            ElevatedButton(
              onPressed: () {
                if (id.text.trim().isEmpty || name.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, {
                  'model_id': id.text.trim(),
                  'display_name': name.text.trim(),
                  'description': description.text.trim(),
                });
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
    id.dispose();
    name.dispose();
    description.dispose();
    if (result == null) return;
    try {
      if (model == null) {
        await BackendService.client.from('ai_models').insert({
          'provider': 'openrouter',
          ...result,
          'is_active': true,
          'sort_order': _models.length,
        });
      } else {
        await BackendService.client.from('ai_models').update(result).eq('id', model['id']);
      }
      await _loadModels();
      _notify('مدل در دیتابیس ذخیره شد.');
    } catch (e) {
      _notify('ذخیره مدل ناموفق بود: $e');
    }
  }

  Future<void> _toggleAiModel(Map<String, dynamic> model) async {
    try {
      await BackendService.client.from('ai_models')
          .update({'is_active': !(model['is_active'] == true)})
          .eq('id', model['id']);
      await _loadModels();
    } catch (e) {
      _notify('تغییر وضعیت مدل ناموفق بود: $e');
    }
  }

  Future<void> _deleteAiModel(Map<String, dynamic> model) async {
    if (model['model_id'] == 'openrouter/free') {
      _notify('مدل پیش‌فرض رایگان را حذف نکن؛ می‌توانی غیرفعالش کنی.');
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف مدل'),
        content: Text('مدل «${model['display_name']}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('لغو')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await BackendService.client.from('ai_models').delete().eq('id', model['id']);
      await _loadModels();
      _notify('مدل حذف شد.');
    } catch (e) {
      _notify('حذف مدل ناموفق بود: $e');
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
    final basePrice = int.tryParse(_basePrice.text.trim());
    final proPrice = int.tryParse(_price.text.trim());
    final freeMessages = int.tryParse(_freeMessages.text.trim());
    final freeImages = int.tryParse(_freeImages.text.trim());
    final freeFiles = int.tryParse(_freeFiles.text.trim());
    final freeVideos = int.tryParse(_freeVideos.text.trim());
    final economicVoice = int.tryParse(_freeEconomicVoice.text.trim());
    final advancedVoice = int.tryParse(_freeAdvancedVoice.text.trim());
    final proImages = int.tryParse(_proImages.text.trim());
    final proVideos = int.tryParse(_proVideos.text.trim());
    if (basePrice == null || proPrice == null || freeMessages == null ||
        freeImages == null || freeFiles == null || freeVideos == null ||
        economicVoice == null || advancedVoice == null || proImages == null ||
        proVideos == null || basePrice < 0 || proPrice < 0 || freeMessages < 0 ||
        freeImages < 0 || freeFiles < 0 || freeVideos < 0 ||
        economicVoice < 0 || advancedVoice < 0 || proImages < 0 || proVideos < 0) {
      _notify('قیمت‌ها و سهمیه‌ها باید عدد معتبر و غیرمنفی باشند.');
      return;
    }
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
        'pro_price': proPrice.toString(),
        'pro_base_price': basePrice,
        'pro_duration_days': days,
        'free_daily_message_limit': freeMessages,
        'free_daily_image_limit': freeImages,
        'free_daily_file_limit': freeFiles,
        'free_daily_video_limit': freeVideos,
        'free_voice_economic_minutes': economicVoice,
        'free_voice_advanced_minutes': advancedVoice,
        'pro_daily_image_generation_limit': proImages,
        'pro_daily_video_generation_limit': proVideos,
        'ads_enabled': _adsEnabled,
        'ad_banner_enabled': _bannerEnabled,
        'ad_banner_unit_id': _bannerUnit.text.trim(),
        'ad_interstitial_enabled': _interstitialEnabled,
        'ad_interstitial_unit_id': _interstitialUnit.text.trim(),
        'ad_rewarded_enabled': _rewardedEnabled,
        'ad_rewarded_unit_id': _rewardedUnit.text.trim(),
        'announcement': _announcement.text.trim(),
        'payment_provider': 'nextpay',
        'payment_enabled': _paymentEnabled,
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
                      Row(
                        children: [
                          const Expanded(
                            child: Text('نمای کلی وارنیکس',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            tooltip: 'به‌روزرسانی آمار',
                            onPressed: _loadDashboardStats,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 2.25,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        children: [
                          _statCard('کل کاربران', _statValue('total_users'), Icons.people_alt_outlined),
                          _statCard('اشتراک‌های فعال', _statValue('active_pro_users'), Icons.workspace_premium_outlined),
                          _statCard('خریدهای موفق', _statValue('paid_orders'), Icons.shopping_bag_outlined),
                          _statCard('پرداخت‌های در انتظار', _statValue('pending_orders'), Icons.hourglass_empty),
                          _statCard('فروش تأییدشده', '${_statValue('revenue')} تومان', Icons.payments_outlined),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('تنظیمات عمومی',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      _field('نام برنامه', _name),
                      _field('مدل هوش مصنوعی', _model),
                      _field('آدرس API', _baseUrl),
                      const Divider(height: 28),
                      Row(
                        children: [
                          const Expanded(child: Text('مدیریت مدل‌های هوش مصنوعی',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          IconButton(
                            tooltip: 'افزودن مدل',
                            onPressed: () => _editAiModel(),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          IconButton(
                            tooltip: 'بارگذاری دوباره مدل‌ها',
                            onPressed: _loadModels,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const Text('فهرست مرکزی مدل‌ها در دیتابیس ذخیره می‌شود؛ افزودن یا غیرفعال‌کردن مدل نیاز به انتشار APK ندارد.',
                        style: TextStyle(color: Colors.white60)),
                      if (_models.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('هنوز مدلی ثبت نشده است.'),
                        ),
                      ..._models.map((model) => Card(
                        color: const Color(0xFF211A35),
                        child: ListTile(
                          leading: Icon(
                            model['is_active'] == true ? Icons.check_circle : Icons.pause_circle,
                            color: model['is_active'] == true ? Colors.greenAccent : Colors.white54,
                          ),
                          title: Text(model['display_name']?.toString() ?? model['model_id'].toString()),
                          subtitle: Text('${model['model_id']} • ${model['is_active'] == true ? 'فعال' : 'غیرفعال'}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _editAiModel(model);
                              if (value == 'toggle') _toggleAiModel(model);
                              if (value == 'delete') _deleteAiModel(model);
                              if (value == 'default') {
                                setState(() => _model.text = model['model_id'].toString());
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'default', child: Text('انتخاب به‌عنوان مدل پیش‌فرض')),
                              const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                              PopupMenuItem(value: 'toggle',
                                child: Text(model['is_active'] == true ? 'غیرفعال‌کردن' : 'فعال‌کردن')),
                              const PopupMenuItem(value: 'delete', child: Text('حذف')),
                            ],
                          ),
                        ),
                      )),

                      _field('دستورالعمل اصلی هوش مصنوعی', _prompt, lines: 5),
                      _field('لینک کانال روبیکا', _rubika),
                      _field('لینک مایکت', _myket),
                      const Divider(height: 28),
                      const Text('پلن حرفه‌ای',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      _field('قیمت پایه نسخه حرفه‌ای (تومان)', _basePrice, keyboard: TextInputType.number),
                      _field('قیمت نهایی پرداخت با کارمزد (تومان)', _price, keyboard: TextInputType.number),
                      _field('مدت اعتبار Pro (روز)', _duration, keyboard: TextInputType.number),
                      const Divider(height: 28),
                      const Text('سهمیه نسخه رایگان و حرفه‌ای', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      _field('پیام متنی رایگان در روز', _freeMessages, keyboard: TextInputType.number),
                      _field('عکس رایگان در روز', _freeImages, keyboard: TextInputType.number),
                      _field('فایل رایگان در روز', _freeFiles, keyboard: TextInputType.number),
                      _field('ویدئوی رایگان در روز', _freeVideos, keyboard: TextInputType.number),
                      _field('دقیقه صوت اقتصادی رایگان در روز', _freeEconomicVoice, keyboard: TextInputType.number),
                      _field('دقیقه صوت پیشرفته رایگان در روز', _freeAdvancedVoice, keyboard: TextInputType.number),
                      _field('تولید تصویر Pro در روز', _proImages, keyboard: TextInputType.number),
                      _field('تولید ویدئو Pro در روز', _proVideos, keyboard: TextInputType.number),
                      const Divider(height: 28),
                      const Text('مدیریت تبلیغات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      SwitchListTile(
                        value: _adsEnabled,
                        onChanged: (value) => setState(() => _adsEnabled = value),
                        title: const Text('فعال بودن سیستم تبلیغات'),
                      ),
                      SwitchListTile(
                        value: _bannerEnabled,
                        onChanged: (value) => setState(() => _bannerEnabled = value),
                        title: const Text('تبلیغ بنری'),
                        subtitle: const Text('جایگاه پیش‌فرض: پایین صفحه خانه'),
                      ),
                      _field('شناسه تبلیغ بنری', _bannerUnit),
                      SwitchListTile(
                        value: _interstitialEnabled,
                        onChanged: (value) => setState(() => _interstitialEnabled = value),
                        title: const Text('تبلیغ تمام‌صفحه'),
                      ),
                      _field('شناسه تبلیغ تمام‌صفحه', _interstitialUnit),
                      SwitchListTile(
                        value: _rewardedEnabled,
                        onChanged: (value) => setState(() => _rewardedEnabled = value),
                        title: const Text('تبلیغ جایزه‌دار'),
                      ),
                      _field('شناسه تبلیغ جایزه‌دار', _rewardedUnit),
                      SwitchListTile(
                        value: _paymentEnabled,
                        onChanged: (value) => setState(() => _paymentEnabled = value),
                        title: const Text('فعال‌سازی پرداخت نکست‌پی'),
                        subtitle: const Text('فقط پس از ثبت کلید محرمانه نکست‌پی در تنظیمات سرور فعالش کن.'),
                      ),
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
                              PopupMenuItem(value: 'pro', child: Text('فعال‌سازی نسخه حرفه‌ای')),
                              PopupMenuItem(value: 'free', child: Text('بازگشت به نسخه رایگان')),
                              PopupMenuItem(value: 'admin', child: Text('اعطای دسترسی مالک')),
                              PopupMenuItem(value: 'user', child: Text('حذف دسترسی مالک')),
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
      _name, _model, _baseUrl, _prompt, _rubika, _myket, _price, _duration,
      _basePrice, _freeMessages, _freeImages, _freeFiles, _freeVideos,
      _freeEconomicVoice, _freeAdvancedVoice, _proImages, _proVideos,
      _bannerUnit, _interstitialUnit, _rewardedUnit, _announcement,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
