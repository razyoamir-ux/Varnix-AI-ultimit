import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/chat_message.dart';
import '../models/app_settings.dart';

class StorageService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _settingsKey = 'app_settings';
  static const String _chatHistoryKey = 'chat_history';
  static const String _apiKeyKey = 'api_key';

  // Settings
  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_settingsKey);
    if (jsonStr == null) return AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(jsonStr));
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  // API Key (secure)
  Future<String?> getApiKey() async {
    return await _secureStorage.read(key: _apiKeyKey);
  }

  Future<void> saveApiKey(String key) async {
    await _secureStorage.write(key: _apiKeyKey, value: key);
  }

  Future<void> deleteApiKey() async {
    await _secureStorage.delete(key: _apiKeyKey);
  }

  // Keep signed-in users' histories isolated; the legacy local history is left untouched.
  String _historyStorageKey(String? userId) => userId == null ? _chatHistoryKey : '${_chatHistoryKey}_${userId}';

  Future<List<ChatMessage>> loadChatHistory({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_historyStorageKey(userId));
    if (jsonStr == null) return [];
    try {
      final List list = jsonDecode(jsonStr);
      return list.map((e) => ChatMessage.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveChatHistory(List<ChatMessage> messages, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = messages.map((m) => m.toJson()).toList();
    await prefs.setString(_historyStorageKey(userId), jsonEncode(jsonList));
  }

  Future<void> clearChatHistory({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyStorageKey(userId));
  }

  // Backup: deliberately excludes API credentials and owner authentication secrets.
  Future<String?> createBackup() async {
    try {
      final settings = await loadSettings();
      final history = await loadChatHistory();

      final safeSettings = settings.toJson();
      final backupData = {
        'version': '2.0',
        'timestamp': DateTime.now().toIso8601String(),
        'settings': safeSettings,
        'chatHistory': history.map((m) => m.toJson()).toList(),
      };

      final dir = await getExternalStorageDirectory();
      if (dir == null) return null;

      // Try Downloads
      Directory downloadsDir;
      try {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = dir;
        }
      } catch (_) {
        downloadsDir = dir;
      }

      final fileName =
          'varnix_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsString(jsonEncode(backupData));
      return file.path;
    } catch (e) {
      return null;
    }
  }

  Future<bool> restoreBackup(String jsonContent) async {
    try {
      final data = jsonDecode(jsonContent);
      if (data['settings'] != null) {
        await saveSettings(AppSettings.fromJson(data['settings']));
      }
      if (data['chatHistory'] != null) {
        final list = (data['chatHistory'] as List)
            .map((e) => ChatMessage.fromJson(e))
            .toList();
        await saveChatHistory(list);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
