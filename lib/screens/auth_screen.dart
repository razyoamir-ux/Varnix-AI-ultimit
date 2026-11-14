import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/backend_service.dart';
import 'home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: BackendService.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (BackendService.client.auth.currentSession != null) return const HomeScreen();
        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  bool _hidePassword = true;

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@') || password.length < 6) {
      _notice('ایمیل معتبر و رمز عبور حداقل ۶ کاراکتری وارد کنید.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_isSignUp) {
        final result = await BackendService.client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: 'com.varnix.ai://login-callback/',
          data: {'display_name': _name.text.trim()},
        );
        if (mounted && result.session == null) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('به وارنیکس خوش آمدی!'),
              content: const Text('از ثبت‌نامت متشکریم ❤️ حساب تو ساخته شد. لطفاً ایمیلت را تأیید کن و سپس وارد برنامه شو.'),
              actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ادامه'))],
            ),
          );
        } else if (mounted) {
          _notice('از ثبت‌نامت متشکریم؛ به وارنیکس خوش آمدی!');
        }
      } else {
        await BackendService.client.auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      _notice(e.message);
    } catch (e) {
      _notice('خطا: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _notice('ابتدا ایمیلتان را وارد کنید.');
      return;
    }
    try {
      await BackendService.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.varnix.ai://login-callback/',
      );
      _notice('لینک بازیابی رمز برایتان ایمیل شد.');
    } on AuthException catch (e) {
      _notice(e.message);
    } catch (_) {
      _notice('ارسال ایمیل بازیابی انجام نشد.');
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F0F1A), Color(0xFF21133D), Color(0xFF0D0D1A)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.auto_awesome, size: 66, color: Color(0xFFA78BFA)),
                      const SizedBox(height: 12),
                      const Text('Varnix AI', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_isSignUp ? 'ساخت حساب کاربری' : 'ورود به حساب کاربری',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 17)),
                      const SizedBox(height: 28),
                      if (_isSignUp) ...[
                        _field(_name, 'نام نمایشی', Icons.person_outline),
                        const SizedBox(height: 14),
                      ],
                      _field(_email, 'ایمیل', Icons.email_outlined,
                        keyboard: TextInputType.emailAddress),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: _hidePassword,
                        decoration: InputDecoration(
                          labelText: 'رمز عبور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF252540),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                          ),
                          child: _busy
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(_isSignUp ? 'ساخت حساب' : 'ورود'),
                        ),
                      ),
                      if (!_isSignUp)
                        TextButton(onPressed: _busy ? null : _resetPassword,
                          child: const Text('فراموشی رمز عبور؟')),
                      TextButton(
                        onPressed: _busy ? null : () => setState(() => _isSignUp = !_isSignUp),
                        child: Text(_isSignUp ? 'قبلاً حساب ساخته‌اید؟ ورود' : 'حساب ندارید؟ ثبت‌نام کنید'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboard}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF252540),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }
}
