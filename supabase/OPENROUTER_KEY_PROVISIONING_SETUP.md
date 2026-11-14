# Varnix OpenRouter user-key provisioning setup

This feature creates one OpenRouter API key per authenticated Varnix account through the official Management API.

## One-time owner setup

1. Sign in to OpenRouter and create a **Management API Key** with write access to API keys. Give it an expiration date. It is not an inference key.
2. In the Supabase project dashboard, open **Edge Functions → Secrets** and add:
   - `OPENROUTER_MANAGEMENT_KEY` = the Management API Key created above
   - `OPENROUTER_USER_KEY_LIMIT_USD` = `1` (optional; defaults to 1 USD)
3. Run `supabase/openrouter_key_provisioning.sql` in the Supabase SQL Editor.
4. Deploy the function from the repository root:
   ```sh
   supabase functions deploy provision-openrouter-key --project-ref gwhlihrijgpdvcpleodi
   ```
5. Build and publish the updated Android app.

## Security and billing

- Never put the Management API Key in Flutter code, app configuration, GitHub commits, or the APK. It belongs only in Supabase Edge Function Secrets.
- Only a signed-in Varnix user can request a key for their own account.
- Each generated key has a daily USD limit (default 1 USD). A new key can be issued once every 24 hours; the previous Varnix-issued key is deleted when the replacement is stored.
- The generated key belongs to the OpenRouter account connected to Varnix's Management API Key. Its usage is charged to that OpenRouter account's available balance, not to the end user's personal OpenRouter account.
- OpenRouter returns the plaintext key only at creation. Varnix stores only the key hash and displays the plaintext once in the app. The user must copy and store it securely.
- The existing Varnix chat proxy continues to use the separate `OPENROUTER_API_KEY` secret. This feature provisions external-use keys; it does not replace the chat proxy key.
