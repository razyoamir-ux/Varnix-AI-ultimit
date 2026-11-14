import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/backend_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _conversationId;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  Future<void> _loadConversation() async {
    try {
      final rows = await BackendService.client
          .from('conversations')
          .select('id')
          .order('updated_at', ascending: false)
          .limit(1);
      if (rows.isNotEmpty) {
        _conversationId = rows.first['id'] as String;
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

  Future<String> _ensureConversation(String firstMessage) async {
    if (_conversationId != null) return _conversationId!;
    final row = await BackendService.client.from('conversations').insert({
      'user_id': BackendService.currentUser!.id,
      'title': firstMessage.length > 48 ? '${firstMessage.substring(0, 48)}…' : firstMessage,
    }).select('id').single();
    _conversationId = row['id'] as String;
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
      final answer = await BackendService.sendChat(messages: history);
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
    _scrollToBottom();
  }

  Future<void> _newConversation() async {
    setState(() {
      _conversationId = null;
      _messages.clear();
    });
  }

  Future<void> _signOut() async {
    await BackendService.signOut();
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
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1030),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Varnix AI', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('دستیار هوشمند شما', style: TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
          actions: [
            IconButton(tooltip: 'گفتگوی جدید', onPressed: _newConversation,
              icon: const Icon(Icons.add_comment_outlined)),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') _signOut();
                if (value == 'email') _showError(email);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'email', child: Text('حساب کاربری')),
                PopupMenuItem(value: 'logout', child: Text('خروج از حساب')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 54, color: Color(0xFFA78BFA)),
                                SizedBox(height: 16),
                                Text('سلام! من وارنیکس هستم.',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                Text('هر سؤالی داری بپرس تا با هم شروع کنیم.',
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
                            return MessageBubble(message: message, isUser: message.role == 'user');
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
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
