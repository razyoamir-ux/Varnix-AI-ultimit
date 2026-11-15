import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';

/// Per-account cloud history. Existing local history is preserved and uploaded
/// when the account has no cloud messages yet. Remote history is never deleted.
class CloudChatService {
  final SupabaseClient _db = Supabase.instance.client;
  String? _conversationId;

  Future<String?> _ensureConversation() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    if (_conversationId != null) return _conversationId;

    final rows = await _db
        .from('conversations')
        .select('id')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false)
        .limit(1);
    if (rows.isNotEmpty) {
      _conversationId = rows.first['id'].toString();
      return _conversationId;
    }

    final created = await _db
        .from('conversations')
        .insert({'user_id': user.id, 'title': 'گفتگوی جدید'})
        .select('id')
        .single();
    _conversationId = created['id'].toString();
    return _conversationId;
  }

  String _key(ChatMessage m) =>
      '${m.role}| ${m.timestamp.toUtc().millisecondsSinceEpoch}| ${m.content}';

  Future<List<ChatMessage>> loadOrSyncLocal(List<ChatMessage> local) async {
    final user = _db.auth.currentUser;
    if (user == null) return local;
    final conversationId = await _ensureConversation();
    if (conversationId == null) return local;

    final rows = await _db
        .from('messages')
        .select('id,role,content,created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    final remote = rows.map((row) => ChatMessage(
      id: row['id'].toString(),
      role: row['role'].toString(),
      content: row['content'].toString(),
      timestamp: DateTime.parse(row['created_at'].toString()).toLocal(),
    )).toList();

    if (remote.isEmpty && local.isNotEmpty) {
      await _insertMessages(local, user.id, conversationId);
      await _touchConversation(conversationId);
      return local;
    }

    final known = remote.map(_key).toSet();
    final missing = local.where((m) => !known.contains(_key(m))).toList();
    if (missing.isNotEmpty) {
      await _insertMessages(missing, user.id, conversationId);
      remote.addAll(missing);
      remote.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      await _touchConversation(conversationId);
    }
    return remote;
  }

  Future<void> syncMessage(ChatMessage message) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    final conversationId = await _ensureConversation();
    if (conversationId == null) return;
    await _insertMessages([message], user.id, conversationId);
    await _touchConversation(conversationId);
  }

  Future<void> _insertMessages(
    List<ChatMessage> messages,
    String userId,
    String conversationId,
  ) async {
    if (messages.isEmpty) return;
    await _db.from('messages').insert(messages.map((m) => {
      'conversation_id': conversationId,
      'user_id': userId,
      'role': m.role == 'assistant' ? 'assistant' : 'user',
      'content': m.content,
      'created_at': m.timestamp.toUtc().toIso8601String(),
    }).toList());
  }

  Future<void> _touchConversation(String conversationId) async {
    await _db.from('conversations').update({
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', conversationId);
  }

  /// Starts a new conversation without deleting any previous cloud messages.
  Future<void> startNewConversation() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      _conversationId = null;
      return;
    }
    final created = await _db
        .from('conversations')
        .insert({'user_id': user.id, 'title': 'گفتگوی جدید'})
        .select('id')
        .single();
    _conversationId = created['id'].toString();
  }
}
