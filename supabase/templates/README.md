# Supabase email confirmation template

The branded Persian signup-confirmation email is in `confirmation.html`.

## Apply it to the active Supabase project

1. Open **Authentication → Email Templates → Confirm signup**.
2. Set the subject to: `ایمیل خود را برای فعال‌سازی وارنیکس تأیید کنید`.
3. Paste the full contents of `confirmation.html` into the message body and save.
4. In **Authentication → URL Configuration → Redirect URLs**, add this exact callback:
   `com.varnix.ai.ultimateplus://login-callback/`
5. If older Varnix APKs are still in use, also allow:
   `com.varnix.ai://login-callback/`

The app uses `supabase_flutter` deep-link handling; the Android manifest registers the callback schemes. The redirect must also be allow-listed in the Supabase dashboard or Supabase can fall back to the Site URL.

**Delivery note:** changing the template does not configure a custom SMTP provider. The default Supabase sender may be unsuitable for production delivery; configure a verified SMTP provider before public release.
