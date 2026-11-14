# Google sign-in setup for Varnix AI

The app now offers Google OAuth from the authentication screen. Google OAuth does not require a separate email-confirmation step: Google authenticates the account and Supabase creates/signs in the user.

## One-time Supabase setup

1. Open the Supabase project Authentication → Sign In / Providers → Google.
2. Enable Google and enter the OAuth Client ID and Client Secret created in Google Cloud Console.
3. In Google Cloud Console, configure the OAuth consent screen and create an OAuth 2.0 Web application client.
4. Add this Authorized redirect URI to the Google OAuth client:
   `https://gwhlihrijgpdvcpleodi.supabase.co/auth/v1/callback`
5. In Supabase Authentication → URL Configuration, add this app callback to the Redirect URLs allow-list:
   `com.varnix.ai://login-callback/`
6. Save the provider settings.

## App behavior

- The sign-in screen's “ورود / ثبت‌نام با Google” button opens Google's OAuth flow in the external browser.
- After Google consent, Supabase redirects to the app callback and the Supabase Flutter SDK restores the session.
- The existing email/password registration remains available and may still require email confirmation depending on the Supabase email-confirmation setting. Google sign-in bypasses that separate email-confirmation step.
- This feature uses the same Supabase Auth user/profile flow and does not disable email confirmation globally.

Never put the Google Client Secret in the Flutter app, GitHub source, or a chat message. Enter it only in the Supabase provider configuration.
