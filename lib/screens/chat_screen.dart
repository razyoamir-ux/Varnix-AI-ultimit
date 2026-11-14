import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import '../services/backend_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import 'owner_panel_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final String? initialPrompt;
  final bool supportMode;
  const ChatScreen({super.key, this.initialPrompt, this.supportMode = false});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _assistants = [];
  String? _selectedAssistantId;
  String _selectedAssistantName = 'وارنیکس';
  String _selectedAssistantIcon = '✨';
  String? _conversationId;
  bool _loading = true;
  bool _sending = false;
  bool _isAdmin = false;
  String _appName = 'Varnix AI';
  String _announcement = '';
  String _rubikaUrl = '';
  String _myketUrl = '';
  String _planCode = 'free';
  String _userInstructions = '';
  String? _planExpiresAt;
  RealtimeChannel? _configChannel;

  @override
  void initState() {
    super.initState();
    _loadUserInstructions();
    _loadConversation().then((_) {
      if (widget.initialPrompt != null && mounted) {
        _controller.text = widget.initialPrompt!;
      }
    });
  }

  Future<void> _loadUserInstructions() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _userInstructions = prefs.getString('varnix_ai_user_instructions') ?? '');
  }

  Future<void> _showInstructionsEditor() async {
    final controller = TextEditingController(text: _userInstructions);
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('شخصی‌سازی هوش مصنوعی'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('به وارنیکس بگو دوست داری چطور پاسخ بدهد؛ مثلاً لحن، میزان جزئیات یا زبان پاسخ. این تنظیم فقط برای حساب و دستگاه فعلی ذخیره می‌شود.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 7,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'مثلاً: پاسخ‌ها را کوتاه، دوستانه و به زبان فارسی بنویس.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ذخیره')),
        ],
      ),
    );
    if (shouldSave == true) {
      final value = controller.text.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('varnix_ai_user_instructions', value);
      if (mounted) setState(() => _userInstructions = value);
    }
    controller.dispose();
  }

  Future<void> _loadConversation() async {
    try {
      _isAdmin = await BackendService.isCurrentUserAdmin();
      if (widget.supportMode) { _selectedAssistantName = 'دستیار راهنمای وارنیکس'; _selectedAssistantIcon = '🛟'; }
      final config = await BackendService.loadAppConfig();
      _appName = config['app_name']?.toString() ?? 'Varnix AI';
      _announcement = config['announcement']?.toString() ?? '';
      _rubikaUrl = config['rubika_url']?.toString() ?? '';
      _myketUrl = config['myket_url']?.toString() ?? '';
      final profile = await BackendService.client
          .from('profiles')
          .select('plan_code,plan_expires_at')
          .eq('id', BackendService.currentUser!.id)
          .maybeSingle();
      _planCode = profile?['plan_code']?.toString() ?? 'free';
      _planExpiresAt = profile?['plan_expires_at']?.toString();
      final assistantRows = await BackendService.client
          .from('assistants')
          .select('id,name,icon')
          .eq('is_active', true)
          .order('sort_order');
      _assistants = assistantRows.map((row) => Map<String, dynamic>.from(row)).toList();
      _configChannel = BackendService.client
          .channel('varnix-app-config')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_config',
            callback: (payload) {
              final record = payload.newRecord;
              if (!mounted || record.isEmpty) return;
              setState(() {
                _appName = record['app_name']?.toString() ?? _appName;
                _announcement = record['announcement']?.toString() ?? _announcement;
                _rubikaUrl = record['rubika_url']?.toString() ?? _rubikaUrl;
                _myketUrl = record['myket_url']?.toString() ?? _myketUrl;
              });
            },
          )
          .subscribe();
      await _refreshConversations();
      if (_conversations.isNotEmpty) {
        _conversationId = _conversations.first['id'] as String;
        final stored = await BackendService.client
            .from('messages')
            .select('id,role,content,created_at')
            .eq('conversation_id', _conversationId!)
            .order('created_at');
        _messages
          ..clear()
          ..addAll(stored.map((row) => ChatMessage(
            id: row['id'].toString(),
            role: row['role'].toString(),
            content: row['content'].toString(),
            timestamp: DateTime.parse(row['created_at'].toString()).toLocal(),
          )));
      }
    } catch (e) {
      _showError('بارگذاری گفتگو ناموفق بود: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _refreshConversations() async {
    final rows = await BackendService.client
        .from('conversations')
        .select('id,title,updated_at')
        .order('updated_at', ascending: false);
    _conversations = rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> _openConversation(String id) async {
    Navigator.of(context).pop();
    setState(() {
      _loading = true;
      _conversationId = id;
      _messages.clear();
    });
    try {
      final stored = await BackendService.client
          .from('messages')
          .select('id,role,content,created_at')
          .eq('conversation_id', id)
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _messages.addAll(stored.map((row) => ChatMessage(
          id: row['id'].toString(),
          role: row['role'].toString(),
          content: row['content'].toString(),
          timestamp: DateTime.parse(row['created_at'].toString()).toLocal(),
        )));
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showError('بازکردن گفتگو ناموفق بود: $e');
    }
  }

  Future<String> _ensureConversation(String firstMessage) async {
    if (_conversationId != null) return _conversationId!;
    final row = await BackendService.client.from('conversations').insert({
      'user_id': BackendService.currentUser!.id,
      'title': firstMessage.length > 48 ? '${firstMessage.substring(0, 48)}…' : firstMessage,
    }).select('id').single();
    _conversationId = row['id'] as String;
    await _refreshConversations();
    if (mounted) setState(() {});
    return _conversationId!;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final user = BackendService.currentUser;
    if (user == null) return;

    setState(() {
      _sending = true;
      _controller.clear();
      _messages.add(ChatMessage(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        role: 'user',
        content: text,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    try {
      final conversationId = await _ensureConversation(text);
      final localUserId = _messages.last.id;
      final savedUser = await BackendService.client.from('messages').insert({
        'conversation_id': conversationId,
        'user_id': user.id,
        'role': 'user',
        'content': text,
      }).select('id,created_at').single();
      final localIndex = _messages.indexWhere((m) => m.id == localUserId);
      if (localIndex >= 0) {
        _messages[localIndex] = ChatMessage(
          id: savedUser['id'].toString(),
          role: 'user',
          content: text,
          timestamp: DateTime.parse(savedUser['created_at'].toString()).toLocal(),
        );
      }

      final history = _messages
          .map((m) => <String, String>{'role': m.role, 'content': m.content})
          .toList();
      final answer = await BackendService.sendChat(messages: history, assistantId: widget.supportMode ? null : _selectedAssistantId, userInstructions: _userInstructions, supportMode: widget.supportMode);
      final saved = await BackendService.client.from('messages').insert({
        'conversation_id': conversationId,
        'user_id': user.id,
        'role': 'assistant',
        'content': answer,
      }).select('id,created_at').single();

      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          id: saved['id'].toString(),
          role: 'assistant',
          content: answer,
          timestamp: DateTime.parse(saved['created_at'].toString()).toLocal(),
        ));
        _sending = false;
      });
      await BackendService.client.from('conversations')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', conversationId);
      await _refreshConversations();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
    _scrollToBottom();
  }

  Future<void> _regenerateLastAnswer() async {
    if (_sending || _conversationId == null) return;
    final lastIndex = _messages.lastIndexWhere((message) => message.role == 'assistant');
    if (lastIndex < 0 || lastIndex != _messages.length - 1) return;
    final oldAnswer = _messages[lastIndex];
    final history = _messages
        .take(lastIndex)
        .map((message) => <String, String>{
              'role': message.role,
              'content': message.content,
            })
        .toList();
    if (history.isEmpty || history.last['role'] != 'user') return;

    setState(() => _sending = true);
    try {
      final answer = await BackendService.sendChat(
        messages: history,
        assistantId: _selectedAssistantId,
        userInstructions: _userInstructions,
      );
      await BackendService.client
          .from('messages')
          .update({'content': answer})
          .eq('id', oldAnswer.id);
      if (!mounted) return;
      setState(() {
        _messages[lastIndex] = ChatMessage(
          id: oldAnswer.id,
          role: 'assistant',
          content: answer,
          timestamp: DateTime.now(),
        );
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showError('ساخت پاسخ دوباره ناموفق بود: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _newConversation() async {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    setState(() {
      _conversationId = null;
      _messages.clear();
    });
  }

  Future<void> _signOut() async {
    await BackendService.signOut();
  }

  Future<void> _openExternal(String value, String emptyMessage) async {
    if (value.trim().isEmpty) {
      _showError(emptyMessage);
      return;
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) {
      _showError('لینک واردشده معتبر نیست.');
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showError('بازکردن لینک انجام نشد: $e');
    }
  }

  void _showAccount(String email) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حساب کاربری'),
        content: Text(email.isEmpty ? 'ایمیل حساب در دسترس نیست.' : email),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('بستن')),
        ],
      ),
    );
  }

  void _showPlan() {
    final pro = _planCode.toLowerCase() == 'pro';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اشتراک وارنیکس'),
        content: Text(pro
            ? 'پلن شما: حرفه‌ای\\nتاریخ پایان: ${_planExpiresAt ?? 'نامشخص'}'
            : 'پلن فعلی شما رایگان است. امکان خرید پلن حرفه‌ای پس از اتصال درگاه پرداخت فعال می‌شود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('متوجه شدم')),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade800),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = BackendService.currentUser?.email ?? '';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: Drawer(
          backgroundColor: const Color(0xFF171326),
          child: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 24, 18, 18),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFFA78BFA), size: 30),
                      SizedBox(width: 12),
                      Text('گفتگوهای وارنیکس',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _newConversation,
                      icon: const Icon(Icons.add),
                      label: const Text('گفتگوی جدید'),
                    ),
                  ),
                ),
                const Divider(height: 24),
                Expanded(
                  child: _conversations.isEmpty
                      ? Center(child: Text('هنوز گفتگویی ندارید',
                          style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: _conversations.length,
                          itemBuilder: (context, index) {
                            final item = _conversations[index];
                            final id = item['id'].toString();
                            return ListTile(
                              selected: id == _conversationId,
                              leading: const Icon(Icons.chat_bubble_outline, size: 20),
                              title: Text(item['title']?.toString() ?? 'گفتگوی جدید',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () => _openConversation(id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1030),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.supportMode ? 'راهنمای وارنیکس' : _appName, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('$_selectedAssistantIcon $_selectedAssistantName', style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
          actions: [
            if (!widget.supportMode) PopupMenuButton<String>(
              tooltip: 'انتخاب دستیار',
              icon: const Icon(Icons.smart_toy_outlined),
              onSelected: (value) {
                setState(() {
                  if (value == '__default__') {
                    _selectedAssistantId = null;
                    _selectedAssistantName = 'وارنیکس';
                    _selectedAssistantIcon = '✨';
                  } else {
                    final assistant = _assistants.firstWhere((a) => a['id'].toString() == value);
                    _selectedAssistantId = value;
                    _selectedAssistantName = assistant['name']?.toString() ?? 'دستیار';
                    _selectedAssistantIcon = assistant['icon']?.toString() ?? '✨';
                  }
                });
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: '__default__', child: Text('✨ وارنیکس (پیش‌فرض)')),
                ..._assistants.map((assistant) => PopupMenuItem(
                  value: assistant['id'].toString(),
                  child: Text('${assistant['icon'] ?? '✨'} ${assistant['name'] ?? 'دستیار'}'),
                )),
              ],
            ),
            IconButton(tooltip: 'گفتگوی جدید', onPressed: _newConversation,
              icon: const Icon(Icons.add_comment_outlined)),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'instructions') _showInstructionsEditor();
                if (value == 'logout') _signOut();
                if (value == 'email') _showAccount(email);
                if (value == 'plan') _showPlan();
                if (value == 'myket') _openExternal(_myketUrl, 'صفحه مایکت پس از انتشار تنظیم می‌شود.');
                if (value == 'rubika') _openExternal(_rubikaUrl, 'لینک کانال روبیکا هنوز تنظیم نشده است.');
                if (value == 'admin') {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const OwnerPanelScreen(),
                  ));
                }
              },
              itemBuilder: (_) => [
                if (_isAdmin)
                  const PopupMenuItem(value: 'admin', child: Text('پنل مدیریت')),
                const PopupMenuItem(value: 'email', child: Text('حساب کاربری')),
                const PopupMenuItem(value: 'plan', child: Text('اشتراک وارنیکس')),
                const PopupMenuItem(value: 'instructions', child: Text('شخصی‌سازی هوش مصنوعی')),
                const PopupMenuItem(value: 'myket', child: Text('امتیاز به وارنیکس در مایکت')),
                if (_rubikaUrl.isNotEmpty)
                  const PopupMenuItem(value: 'rubika', child: Text('کانال روبیکا')),
                const PopupMenuItem(value: 'logout', child: Text('خروج از حساب')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_announcement.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                color: const Color(0xFF30204F),
                child: Text(_announcement, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 54, color: Color(0xFFA78BFA)),
                                SizedBox(height: 16),
                                Text(widget.supportMode ? 'سلام! من دستیار راهنمای وارنیکس هستم.' : 'سلام! من وارنیکس هستم.',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                Text(widget.supportMode ? 'درباره امکانات، تنظیمات، حساب کاربری، پلن‌ها یا خطاهای برنامه سؤال بپرس.' : 'هر سؤالی داری بپرس تا با هم شروع کنیم.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white60)),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: _messages.length + (_sending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_sending && index == _messages.length) {
                              return const TypingIndicator();
                            }
                            final message = _messages[index];
                            return MessageBubble(
                              message: message,
                              isUser: message.role == 'user',
                              onRegenerate: !_sending &&
                                      message.role == 'assistant' &&
                                      index == _messages.length - 1
                                  ? _regenerateLastAnswer
                                  : null,
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'پیامت را بنویس...',
                          filled: true,
                          fillColor: const Color(0xFF252540),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        fixedSize: const Size(48, 48),
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
    _configChannel?.unsubscribe();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
