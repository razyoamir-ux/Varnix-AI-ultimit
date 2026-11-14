-- Varnix AI owner-panel upgrade
-- Run once in Supabase SQL Editor while signed in as project owner.
-- Grants administrators read-only access to user conversations and messages.
-- User access remains limited to their own records.

drop policy if exists "admin reads all conversations" on public.conversations;
create policy "admin reads all conversations" on public.conversations
for select to authenticated using (public.is_admin());

drop policy if exists "admin reads all messages" on public.messages;
create policy "admin reads all messages" on public.messages
for select to authenticated using (public.is_admin());

-- Purchases already have an administrator read policy in schema.sql.
