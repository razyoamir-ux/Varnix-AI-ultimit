import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';

class OwnerPanelScreen extends StatefulWidget {
  final AppSettings settings;
  final String apiKey;

  const OwnerPanelScreen({
    super.key,
    required this.settings,
    required this.apiKey,
  });

  @override
  State<OwnerPanelScreen> createState() => _OwnerPanelScreenState();
}

class _OwnerPanelScreenState extends State<OwnerPanelScreen> {
  final StorageService _storage = StorageService();
  late TextEditingController _aiNameCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _apiUrlCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _systemPromptCtrl;
  late TextEditingController _rubikaCtrl;
  late TextEditingController _paymentLinkCtrl;
  late TextEditingController _myketCtrl;
  late TextEditingController _paymentAmountCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _newPasswordCtrl;
  late TextEditingController _confirmPasswordCtrl;

  bool _isAuthenticated = false;
  bool _obscureKey = true;
  bool _isSaving = false;
  String _currentPassword = '246810';

  @override
  void initState() {
    super.initState();
    _aiNameCtrl = TextEditingController(text: widget.settings.aiName);
    _modelCtrl = TextEditingController(text: widget.settings.model);
    _apiUrlCtrl = TextEditingController(text: widget.settings.apiBaseUrl);
    _apiKeyCtrl = TextEditingController(text: widget.apiKey);
    _systemPromptCtrl = TextEditingController(text: widget.settings.systemPrompt);
    _rubikaCtrl = TextEditingController(text: widget.settings.rubikaChannelLink);
    _paymentLinkCtrl = TextEditingController(text: widget.settings.paymentLink);
    _myketCtrl = TextEditingController(text: widget.settings.myketLink);
    _paymentAmountCtrl = TextEditingController(text: widget.settings.paymentAmount);
    _passwordCtrl = TextEditingController();
    _newPasswordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
    _loadPassword();
  }

  Future<void> _loadPassword() async {
    _currentPassword = await _storage.getOwnerPassword();
  }

  Future<void> _authenticate() async {
    if (_passwordCtrl.text == _currentPassword) {
      setState(() => _isAuthenticated = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رمز اشتباه است'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      final newSettings = AppSettings(
        aiName: _aiNameCtrl.text.trim().isEmpty ? 'وارنیکس' : _aiNameCtrl.text.trim(),
        model: _modelCtrl.text.trim().isEmpty ? 'openrouter/free' : _modelCtrl.text.trim(),
        apiBaseUrl: _apiUrlCtrl.text.trim().isEmpty
            ? 'https://openrouter.ai/api/v1'
            : _apiUrlCtrl.text.trim(),
        systemPrompt: _systemPromptCtrl.text.trim(),
        rubikaChannelLink: _rubikaCtrl.text.trim(),
        paymentLink: _paymentLinkCtrl.text.trim(),
        myketLink: _myketCtrl.text.trim(),
        paymentAmount: _paymentAmountCtrl.text.trim().isEmpty
            ? '۵۰٬۰۰۰ تومان'
            : _paymentAmountCtrl.text.trim(),
        ownerPassword: _currentPassword,
      );
      await _storage.saveSettings(newSettings);
      await _storage.saveApiKey(_apiKeyCtrl.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تنظیمات ذخیره شد'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ذخیره: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordCtrl.text.isEmpty || _newPasswordCtrl.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمز جدید باید حداقل ۴ کاراکتر باشد')),
      );
      return;
    }
    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمزها مطابقت ندارند')),
      );
      return;
    }
    await _storage.saveOwnerPassword(_newPasswordCtrl.text);
    _currentPassword = _newPasswordCtrl.text;
    _newPasswordCtrl.clear();
    _confirmPasswordCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('رمز با موفقیت تغییر کرد'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _backup() async {
    final path = await _storage.createBackup();
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('پشتیبان ذخیره شد:\n$path'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطا در ایجاد پشتیبان'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restore() async {
    try {
      // Simple text input for restore since file_picker may need extra setup
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController();
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Text('بازیابی پشتیبان', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'محتوای فایل JSON پشتیبان را اینجا بچسبانید:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF252540),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('انصراف'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('بازیابی'),
              ),
            ],
          );
        },
      );
      if (result != null && result.isNotEmpty) {
        final ok = await _storage.restoreBackup(result);
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('بازیابی موفق بود. برنامه را ریستارت کنید.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فایل پشتیبان نامعتبر است'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    int maxLines = 1,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF252540),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: suffix,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1030),
          title: const Text('پنل مالک', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: !_isAuthenticated
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 64, color: Color(0xFF8B5CF6)),
                    const SizedBox(height: 24),
                    const Text(
                      'ورود به پنل مالک',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    _buildField(
                      label: 'رمز عبور',
                      controller: _passwordCtrl,
                      obscure: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _authenticate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('ورود', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildField(label: 'نام هوش مصنوعی', controller: _aiNameCtrl),
                  _buildField(label: 'مدل (Model)', controller: _modelCtrl),
                  _buildField(label: 'آدرس API (Endpoint)', controller: _apiUrlCtrl),
                  _buildField(
                    label: 'کلید API',
                    controller: _apiKeyCtrl,
                    obscure: _obscureKey,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureKey ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white54,
                      ),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                  _buildField(
                    label: 'دستورالعمل سیستم (شخصیت)',
                    controller: _systemPromptCtrl,
                    maxLines: 5,
                  ),
                  _buildField(label: 'لینک کانال روبیکا', controller: _rubikaCtrl),
                  _buildField(label: 'لینک پرداخت', controller: _paymentLinkCtrl),
                  _buildField(label: 'مبلغ پرداخت', controller: _paymentAmountCtrl),
                  _buildField(label: 'لینک مایکت', controller: _myketCtrl),
                  const Divider(color: Colors.white12, height: 32),
                  const Text(
                    'تغییر رمز پنل',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildField(label: 'رمز جدید', controller: _newPasswordCtrl, obscure: true),
                  _buildField(label: 'تکرار رمز جدید', controller: _confirmPasswordCtrl, obscure: true),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _changePassword,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA78BFA),
                        side: const BorderSide(color: Color(0xFF7C3AED)),
                      ),
                      child: const Text('تغییر رمز'),
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 32),
                  const Text(
                    'پشتیبان‌گیری',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _backup,
                          icon: const Icon(Icons.backup),
                          label: const Text('ایجاد پشتیبان'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFA78BFA),
                            side: const BorderSide(color: Color(0xFF7C3AED)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _restore,
                          icon: const Icon(Icons.restore),
                          label: const Text('بازیابی'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFA78BFA),
                            side: const BorderSide(color: Color(0xFF7C3AED)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'ذخیره تمام تنظیمات',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _aiNameCtrl.dispose();
    _modelCtrl.dispose();
    _apiUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _systemPromptCtrl.dispose();
    _rubikaCtrl.dispose();
    _paymentLinkCtrl.dispose();
    _myketCtrl.dispose();
    _paymentAmountCtrl.dispose();
    _passwordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }
}
