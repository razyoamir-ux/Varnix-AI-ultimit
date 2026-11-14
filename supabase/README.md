# Varnix AI backend

This folder contains the hosted backend foundation for Varnix AI.

## Required setup (one time)
1. Create a Supabase project.
2. Open **SQL Editor** and run `schema.sql`.
3. Deploy the Edge Function in `functions/chat` as `chat`.
4. Set the Edge Function secret `OPENROUTER_API_KEY` in Supabase. Never put this secret in Flutter source code or GitHub.
5. In the `profiles` table, change the intended owner's `role` to `admin` after that owner has registered. Do this only for the correct account.

## Flutter configuration
The mobile app will use the project's public URL and anon key (these are client configuration, not secrets) to authenticate users and read/write their own data. Row Level Security protects user records. The OpenRouter secret remains server-side.

## Current scope
- Email identity profiles and roles
- Global remote app configuration
- Assistant catalog
- User-owned conversations and messages
- Purchase records with pending/paid/failed states
- Authenticated AI proxy so provider credentials are not shipped in the APK

Payment activation must be performed by a trusted server-side payment verification flow. A client must never be allowed to mark its own purchase as paid.


## Connect the current Flutter app
1. In Supabase, open **Project Settings → API** and copy the **Project URL** and the **anon/public key**.
2. In GitHub, open this repository's **Settings → Secrets and variables → Actions**.
3. Add two repository secrets with these exact names:
   - `SUPABASE_URL` — your Supabase Project URL.
   - `SUPABASE_ANON_KEY` — your Supabase anon/public key.
4. Open **Actions → Build Varnix AI APK** and run the workflow, or push a commit to `varnix-v3-foundation`.
5. Download the generated `varnix-ai-apk` artifact from the completed workflow run.

The current app build reads those values through Dart compile-time defines. If the secrets are not configured, the APK deliberately shows a setup-required screen instead of pretending the cloud service is connected.

## Auth and owner setup
- In Supabase **Authentication → URL Configuration**, set the site URL and allowed redirect URLs for your app's password recovery flow.
- Configure the email provider and decide whether email confirmation is required. Add `com.varnix.ai://login-callback/` to the Supabase Auth allowed redirect URLs for email confirmation and password recovery.
- Register your own account in the app first. Then, in the Supabase SQL Editor, run an update setting only that account's `profiles.role` to `admin`.
- Never put the OpenRouter API key or Supabase service-role key in GitHub repository files, Flutter build arguments, or chat messages. Add only `OPENROUTER_API_KEY` to the Supabase Edge Function secrets.
