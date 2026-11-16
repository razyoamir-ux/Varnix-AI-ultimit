import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import '../models/app_settings.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../services/backend_service.dart';
import '../services/cloud_chat_service.dart';
import 'auth_screen.dart';
import 'owner_panel_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String? assistantInstruction;
  final String? initialPrompt;
  final String? conversationId;
  const ChatScreen({super.key, this.assistantInstruction, this.initialPrompt, this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final StorageService _storage = StorageService();
  final ApiService _api = ApiService();
  final CloudChatService _cloudChat = CloudChatService();

  List<ChatMessage> _messages = [];
  AppSettings _settings = AppSettings();
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isPro = false;
  bool _isAdmin = false;
  String _selectedModel = 'openrouter/free';
  List<Map<String, dynamic>> _availableModels = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null) _controller.text = widget.initialPrompt!;
    _loadData();
  }

  Future<void> _loadData() async {
    final settings = await _storage.loadSettings();
    final chatUserId = Supabase.instance.client.auth.currentUser?.id;
    var history = await _storage.loadChatHistory(userId: chatUserId, conversationId: widget.conversationId);
    if (widget.conversationId == null) {
      try {
        history = await _cloudChat.loadOrSyncLocal(history);
        await _storage.saveChatHistory(history, userId: chatUserId);
      }
      catch (_) {
        // Keep the local history available if cloud sync is temporarily offline.
      }
    }
    final remoteSettings = await BackendService.loadRemoteSettings(settings);
    var isPro = false;
    var isAdmin = false;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client.from('profiles').select('role,plan_code,plan_expires_at').eq('id', user.id).maybeSingle();
        isAdmin = (profile?['role'] ?? '').toString().toLowerCase() == 'admin';
        final plan = (profile?['plan_code'] ?? 'free').toString().toLowerCase();
        final expiry = profile?['plan_expires_at'];
        isPro = isAdmin || plan == 'owner' || (plan == 'pro' && (expiry == null || DateTime.tryParse(expiry.toString())?.isAfter(DateTime.now()) == true));
      }
    } catch (_) {}
    List<Map<String, dynamic>> models = [];
    try {
      final rows = await Supabase.instance.client.from('ai_models').select('model_id,display_name,provider,requires_pro,is_active').eq('is_active', true).order('sort_order');
      models = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}
    if (models.isEmpty) {
      models = [
        {'model_id':'openrouter/free','display_name':'OpenRouter Free','requires_pro':false},
        {'model_id':'deepseek/deepseek-v4.1-flash-1017:free','display_name':'DeepSeek V4.1 Flash','requires_pro':false},
        {'model_id':'nvidia/nemotron-3.5-super-vl:free','display_name':'NVIDIA Nemotron 3.5 Super VL','requires_pro':true},
      ];
    }
    final savedModel = remoteSettings.model;
    await _storage.saveSettings(remoteSettings);
    if (!mounted) return;
    setState(() {
      _settings = remoteSettings;
      _messages = history;
      _isPro = isPro;
      _isAdmin = isAdmin;
      _availableModels = models;
      _selectedModel = models.any((m) => m['model_id'] == savedModel && (isPro || m['requires_pro'] != true))
          ? savedModel
          : (models.firstWhere((m) => m['requires_pro'] != true, orElse: () => models.first)['model_id'] as String);
      _isInitialized = true;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final systemInstruction = widget.assistantInstruction;
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();
    await _storage.saveChatHistory(_messages, userId: Supabase.instance.client.auth.currentUser?.id, conversationId: widget.conversationId);
    if (widget.conversationId == null) { try { await _cloudChat.syncMessage(userMsg); } catch (_) {} }

    try {
      final reply = await _api.sendMessage(
        history: _messages.sublist(0, _messages.length - 1),
        userMessage: text,
        model: _selectedModel,
        systemInstruction: systemInstruction,
      );

      final aiMsg = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        role: 'assistant',
        content: reply,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMsg);
        _isLoading = false;
      });
      await _storage.saveChatHistory(_messages, userId: Supabase.instance.client.auth.currentUser?.id);
      if (widget.conversationId == null) { try { await _cloudChat.syncMessage(aiMsg); } catch (_) {} }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
    _scrollToBottom();
  }

  Future<void> _searchMessages() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('جست‌وجو در گفتگو', style: TextStyle(color: Colors.white)),
        content: TextField(controller: controller, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'عبارت موردنظر را بنویسید', hintStyle: TextStyle(color: Colors.white54)), onSubmitted: (v) => Navigator.pop(ctx, v.trim())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')), TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('جست‌وجو'))],
      )),
    );
    controller.dispose();
    if (query == null || query.isEmpty || !mounted) return;
    final matches = _messages.where((m) => m.content.toLowerCase().contains(query.toLowerCase())).toList();
    await showDialog<void>(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: Text('نتایج جست‌وجو (${matches.length})', style: const TextStyle(color: Colors.white)),
      content: SizedBox(width: double.maxFinite, child: matches.isEmpty
        ? const Text('موردی پیدا نشد.', style: TextStyle(color: Colors.white70))
        : ListView.separated(shrinkWrap: true, itemCount: matches.length, separatorBuilder: (_, __) => const Divider(color: Colors.white12), itemBuilder: (_, i) => ListTile(dense: true, title: Text(matches[i].role == 'user' ? 'پیام شما' : 'پاسخ وارنیکس', style: const TextStyle(color: Colors.white70, fontSize: 12)), subtitle: Text(matches[i].content, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white))))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))],
    )));
  }

  String _conversationText() => _messages.map((m) => '${m.role == 'user' ? 'شما' : _settings.aiName}:\n${m.content}').join('\n\n');

  Future<void> _copyFullConversation() async {
    if (_messages.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('گفتگویی برای کپی وجود ندارد'))); return; }
    await Clipboard.setData(ClipboardData(text: _conversationText()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کل گفتگو کپی شد')));
  }

  Future<void> _shareConversation() async {
    if (_messages.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('گفتگویی برای اشتراک‌گذاری وجود ندارد'))); return; }
    await Share.share(_conversationText(), subject: 'گفتگو با وارنیکس');
  }
  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('پاک کردن تاریخچه', style: TextStyle(color: Colors.white)),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید تمام پیام‌ها پاک شوند؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('پاک کردن', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _storage.clearChatHistory(userId: Supabase.instance.client.auth.currentUser?.id, conversationId: widget.conversationId);
      // Start a fresh cloud conversation only for the main chat; assistant sessions stay local and separate.
      if (widget.conversationId == null) { try { await _cloudChat.startNewConversation(); } catch (_) {} }
      setState(() => _messages = []);
    }
  }

  Future<void> _openLink(String url, String emptyMsg) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMsg), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لینک نامعتبر است'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _chooseModel() async {
    final selectable = _availableModels.where((m) => _isPro || m['requires_pro'] != true).toList();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('انتخاب مدل هوش مصنوعی', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
          ...selectable.map((m) => ListTile(
            leading: Icon(m['requires_pro'] == true ? Icons.workspace_premium : Icons.auto_awesome, color: const Color(0xFFA78BFA)),
            title: Text((m['display_name'] ?? m['model_id']).toString(), style: const TextStyle(color: Colors.white)),
            subtitle: Text(m['requires_pro'] == true ? 'حرفه‌ای' : 'رایگان', style: const TextStyle(color: Colors.white54)),
            trailing: _selectedModel == m['model_id'] ? const Icon(Icons.check_circle, color: Colors.greenAccent) : null,
            onTap: () {
              setState(() { _selectedModel = m['model_id'].toString(); _settings.model = _selectedModel; });
              _storage.saveSettings(_settings);
              Navigator.pop(ctx);
            },
          )),
          if (!_isPro && _availableModels.any((m) => m['requires_pro'] == true))
            const Padding(padding: EdgeInsets.all(12), child: Text('برای استفاده از مدل‌های حرفه‌ای، پلن حرفه‌ای لازم است.', style: TextStyle(color: Colors.orangeAccent))),
        ])),
      ),
    );
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.campaign, color: Color(0xFFA78BFA)),
                  title: const Text('کانال ما', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openLink(
                      _settings.rubikaChannelLink,
                      'لینک کانال روبیکا تنظیم نشده است.',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payment, color: Color(0xFFA78BFA)),
                  title: Text(
                    'پرداخت (${_settings.paymentAmount})',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openLink(
                      _settings.paymentLink,
                      'لینک پرداخت تنظیم نشده است.',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.star_rate, color: Color(0xFFA78BFA)),
                  title: const Text('امتیاز به وارنیکس', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openLink(
                      _settings.myketLink,
                      'به‌زودی در مایکت',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.rate_review, color: Color(0xFFA78BFA)),
                  title: const Text('ثبت نظر در مایکت', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openLink(
                      _settings.myketLink,
                      'به‌زودی در مایکت',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.search, color: Color(0xFFA78BFA)),
                  title: const Text('جست‌وجو در گفتگو', style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(ctx); _searchMessages(); },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_all, color: Color(0xFFA78BFA)),
                  title: const Text('کپی کل گفتگو', style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(ctx); _copyFullConversation(); },
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: Color(0xFFA78BFA)),
                  title: const Text('اشتراک‌گذاری گفتگو', style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(ctx); _shareConversation(); },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('پاک کردن تاریخچه', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _clearHistory();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sync, color: Color(0xFFA78BFA)),
                  title: const Text('دریافت تنظیمات جدید', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تنظیمات از سرور به‌روزرسانی شد')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.orangeAccent),
                  title: const Text('خروج از حساب کاربری', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Supabase.instance.client.auth.signOut();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                      (route) => false,
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1030),
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  ),
                ),
                child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _settings.aiName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _isLoading ? 'در حال پاسخ‌گویی...' : 'مدل: ${_availableModels.firstWhere((m) => m['model_id'] == _selectedModel, orElse: () => {'display_name': 'پیش‌فرض'})['display_name']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isLoading
                          ? const Color(0xFFA78BFA)
                          : Colors.greenAccent.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (_isAdmin)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings, color: Color(0xFFA78BFA)),
                tooltip: 'پنل مالک',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OwnerPanelScreen()),
                  );
                  if (mounted) await _loadData();
                },
              ),
            IconButton(icon: const Icon(Icons.tune, color: Colors.white70), tooltip: 'انتخاب مدل', onPressed: _chooseModel),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onPressed: _showMenu,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.white.withOpacity(0.15),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'سلام! من ${_settings.aiName} هستم.\nچطور می‌تونم کمکتون کنم؟',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isLoading && index == _messages.length) {
                          return const TypingIndicator();
                        }
                        final msg = _messages[index];
                        return MessageBubble(
                          message: msg,
                          isUser: msg.role == 'user',
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1030),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF252540),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF3B3B5C)),
                        ),
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          maxLines: 4,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'پیام خود را بنویسید...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _isLoading ? null : _sendMessage,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _isLoading
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                ),
                          color: _isLoading ? Colors.grey.shade700 : null,
                        ),
                        child: Icon(
                          _isLoading ? Icons.hourglass_top : Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
