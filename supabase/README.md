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
