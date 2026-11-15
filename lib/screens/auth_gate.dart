import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'welcome_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) return const AuthScreen();
        if (session.user.emailConfirmedAt == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final current = client.auth.currentUser;
            if (current != null && current.emailConfirmedAt == null) {
              client.auth.signOut();
            }
          });
          return const AuthScreen();
        }
        return const WelcomeScreen();
      },
    );
  }
}
