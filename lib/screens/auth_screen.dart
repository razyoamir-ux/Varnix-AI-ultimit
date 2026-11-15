import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hidePassword = true;
  String _message = '';

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _message = 'ایمیل معتبر وارد کن.');
      return;
    }
    if (password.length < 8) {
      setState(() => _message = 'رمز عبور باید حداقل ۸ کاراکتر باشد.');
      return;
    }

    setState(() { _busy = true; _message = ''; });
    try {
      if (_register) {
        final result = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: 'com.varnix.ai.ultimateplus://login-callback/',
        );
        if (!mounted) return;
        if (result.session == null) {
          setState(() => _message = 'حساب ساخته شد. ایمیلت را باز کن و روی لینک تأیید بزن؛ بعد از تأیید به وارنیکس برمی‌گردی.');
          return;
        }
        // Never grant app access from the sign-up action itself.
        // This also protects users if email confirmation is accidentally disabled server-side.
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          setState(() => _message = 'تأیید ایمیل در سرور فعال نیست. تا فعال شدن تأیید ایمیل نمی‌توانی وارد شوی.');
        }
        return;
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'اتصال ناموفق بود. اینترنت را بررسی کن.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 22),
                  const Text('Varnix AI', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(_register ? 'ساخت حساب کاربری' : 'ورود به حساب وارنیکس', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'ایمیل', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _hidePassword,
                    decoration: InputDecoration(
                      labelText: 'رمز عبور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  if (_message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFB4AB))),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? 'لطفاً صبر کن...' : (_register ? 'ساخت حساب' : 'ورود')),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() { _register = !_register; _message = ''; }),
                    child: Text(_register ? 'از قبل حساب داری؟ وارد شو' : 'حساب نداری؟ ثبت‌نام کن'),
                  ),
                  const SizedBox(height: 8),
                  const Text('حساب کاربری و تنظیمات به سرور امن وارنیکس متصل می‌شوند.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
