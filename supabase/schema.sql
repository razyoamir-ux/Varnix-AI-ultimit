-- Varnix AI v3 backend foundation (Supabase/Postgres)
-- Apply this file in the Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text not null default '',
  role text not null default 'user' check (role in ('user','admin')),
  plan_code text not null default 'free',
  plan_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.app_config (
  id boolean primary key default true check (id = true),
  app_name text not null default 'Varnix AI',
  default_model text not null default 'openrouter/free',
  api_base_url text not null default 'https://openrouter.ai/api/v1',
  system_prompt text not null default 'تو یک دستیار هوشمند فارسی‌زبان به نام وارنیکس هستی. پاسخ‌ها را دقیق، مفید و دوستانه بده.',
  rubika_url text not null default '',
  myket_url text not null default '',
  pro_price text not null default '',
  pro_duration_days integer not null default 30 check (pro_duration_days > 0),
  announcement text not null default '',
  updated_at timestamptz not null default now()
);

insert into public.app_config (id) values (true) on conflict (id) do nothing;

create table if not exists public.assistants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  icon text not null default '✨',
  system_prompt text not null,
  model text not null default 'openrouter/free',
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_code text not null,
  amount numeric(12,2) not null check (amount >= 0),
  currency text not null default 'IRR',
  provider text not null default 'external',
  provider_reference text,
  status text not null default 'pending' check (status in ('pending','paid','failed','refunded')),
  created_at timestamptz not null default now(),
  verified_at timestamptz
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'گفتگوی جدید',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user','assistant','system')),
  content text not null,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'display_name',''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.app_config enable row level security;
alter table public.assistants enable row level security;
alter table public.purchases enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

drop policy if exists "profile read own or admin" on public.profiles;
create policy "profile read own or admin" on public.profiles
for select using (auth.uid() = id or public.is_admin());
drop policy if exists "profile update own or admin" on public.profiles;
create policy "profile update own or admin" on public.profiles
for update using (auth.uid() = id or public.is_admin())
with check (auth.uid() = id or public.is_admin());

drop policy if exists "config readable by authenticated" on public.app_config;
create policy "config readable by authenticated" on public.app_config
for select to authenticated using (true);
drop policy if exists "admin manages config" on public.app_config;
create policy "admin manages config" on public.app_config
for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "active assistants readable" on public.assistants;
create policy "active assistants readable" on public.assistants
for select to authenticated using (is_active or public.is_admin());
drop policy if exists "admin manages assistants" on public.assistants;
create policy "admin manages assistants" on public.assistants
for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "user reads own purchases" on public.purchases;
create policy "user reads own purchases" on public.purchases
for select to authenticated using (auth.uid() = user_id or public.is_admin());
drop policy if exists "user creates own pending purchase" on public.purchases;
create policy "user creates own pending purchase" on public.purchases
for insert to authenticated with check (auth.uid() = user_id and status = 'pending');
drop policy if exists "admin manages purchases" on public.purchases;
create policy "admin manages purchases" on public.purchases
for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admin reads all conversations" on public.conversations;
create policy "admin reads all conversations" on public.conversations
for select to authenticated using (public.is_admin());

drop policy if exists "admin reads all messages" on public.messages;
create policy "admin reads all messages" on public.messages
for select to authenticated using (public.is_admin());

drop policy if exists "user manages own conversations" on public.conversations;
create policy "user manages own conversations" on public.conversations
for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "user manages own messages" on public.messages;
create policy "user manages own messages" on public.messages
for all to authenticated using (
  auth.uid() = user_id and exists (
    select 1 from public.conversations c
    where c.id = conversation_id and c.user_id = auth.uid()
  )
) with check (
  auth.uid() = user_id and exists (
    select 1 from public.conversations c
    where c.id = conversation_id and c.user_id = auth.uid()
  )
);

grant usage on schema public to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.app_config to authenticated;
grant select, insert, update, delete on public.assistants to authenticated;
grant select, insert on public.purchases to authenticated;
grant select, insert, update, delete on public.conversations to authenticated;
grant select, insert, update, delete on public.messages to authenticated;

-- Security hardening: users may edit only their display name directly.
-- Role and subscription changes are reserved for administrators.
revoke update on public.profiles from authenticated;
grant update (display_name) on public.profiles to authenticated;

create or replace function public.admin_update_profile(
  target_user_id uuid,
  new_role text default null,
  new_plan_code text default null,
  new_plan_expires_at timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Administrator access required';
  end if;
  if new_role is not null and new_role not in ('user', 'admin') then
    raise exception 'Invalid role';
  end if;
  update public.profiles
  set role = coalesce(new_role, role),
      plan_code = coalesce(new_plan_code, plan_code),
      plan_expires_at = case
        when new_plan_expires_at is not null then new_plan_expires_at
        else plan_expires_at
      end,
      updated_at = now()
  where id = target_user_id;
end;
$$;

revoke all on function public.admin_update_profile(uuid, text, text, timestamptz) from public;
grant execute on function public.admin_update_profile(uuid, text, text, timestamptz) to authenticated;


-- Enable live global configuration updates for connected app instances.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'app_config'
     ) then
    alter publication supabase_realtime add table public.app_config;
  end if;
end;
$$;


-- Subscription tiers and server-enforced daily AI quotas.
create table if not exists public.subscription_plans (
  plan_code text primary key,
  display_name text not null,
  daily_request_limit integer not null check (daily_request_limit > 0),
  max_output_tokens integer not null check (max_output_tokens > 0),
  price_label text not null default 'قیمت از پنل مالک تعیین می‌شود',
  duration_days integer not null default 30 check (duration_days > 0),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  updated_at timestamptz not null default now()
);
insert into public.subscription_plans
  (plan_code, display_name, daily_request_limit, max_output_tokens, price_label, duration_days, sort_order)
values
  ('free', 'رایگان', 20, 1024, '۰ تومان', 30, 0),
  ('pro', 'پرو', 100, 2048, 'قیمت از پنل مالک تعیین می‌شود', 30, 1),
  ('pro_max', 'پرو مکس', 300, 4096, 'قیمت از پنل مالک تعیین می‌شود', 30, 2),
  ('ultra_max', 'اولترا مکس', 800, 8192, 'قیمت از پنل مالک تعیین می‌شود', 30, 3)
on conflict (plan_code) do update set
  display_name = excluded.display_name,
  daily_request_limit = excluded.daily_request_limit,
  max_output_tokens = excluded.max_output_tokens,
  sort_order = excluded.sort_order,
  updated_at = now();

create table if not exists public.ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null,
  request_count integer not null default 0 check (request_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, usage_date)
);
alter table public.subscription_plans enable row level security;
alter table public.ai_usage enable row level security;
drop policy if exists "plans readable by authenticated" on public.subscription_plans;
create policy "plans readable by authenticated" on public.subscription_plans
for select to authenticated using (is_active or public.is_admin());
drop policy if exists "admins manage subscription plans" on public.subscription_plans;
create policy "admins manage subscription plans" on public.subscription_plans
for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "users read own ai usage" on public.ai_usage;
create policy "users read own ai usage" on public.ai_usage
for select to authenticated using (auth.uid() = user_id or public.is_admin());
grant select on public.subscription_plans to authenticated;
grant select on public.ai_usage to authenticated;

create or replace function public.admin_update_profile(
  target_user_id uuid,
  new_role text default null,
  new_plan_code text default null,
  new_plan_expires_at timestamptz default null
)
returns void language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Administrator access required'; end if;
  if new_role is not null and new_role not in ('user', 'admin') then raise exception 'Invalid role'; end if;
  if new_plan_code is not null and new_plan_code not in ('free', 'pro', 'pro_max', 'ultra_max') then raise exception 'Invalid plan code'; end if;
  update public.profiles
  set role = coalesce(new_role, role),
      plan_code = coalesce(new_plan_code, plan_code),
      plan_expires_at = case when new_plan_expires_at is not null then new_plan_expires_at else plan_expires_at end,
      updated_at = now()
  where id = target_user_id;
end;
$$;
revoke all on function public.admin_update_profile(uuid, text, text, timestamptz) from public;
grant execute on function public.admin_update_profile(uuid, text, text, timestamptz) to authenticated;

create or replace function public.consume_ai_quota()
returns jsonb language plpgsql security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_plan_code text := 'free';
  v_expires_at timestamptz;
  v_daily_limit integer := 20;
  v_max_tokens integer := 1024;
  v_today date := (now() at time zone 'UTC')::date;
  v_used integer;
  v_reset_at timestamptz := ((date_trunc('day', now() at time zone 'UTC') + interval '1 day') at time zone 'UTC');
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  select plan_code, plan_expires_at into v_plan_code, v_expires_at
  from public.profiles where id = v_user_id;
  if v_plan_code is null then v_plan_code := 'free'; end if;
  if v_plan_code <> 'free' and v_expires_at is not null and v_expires_at <= now() then v_plan_code := 'free'; end if;
  select daily_request_limit, max_output_tokens into v_daily_limit, v_max_tokens
  from public.subscription_plans where plan_code = v_plan_code and is_active = true;
  if not found then v_plan_code := 'free'; v_daily_limit := 20; v_max_tokens := 1024; end if;
  insert into public.ai_usage (user_id, usage_date, request_count, updated_at)
  values (v_user_id, v_today, 1, now())
  on conflict (user_id, usage_date) do update
    set request_count = public.ai_usage.request_count + 1, updated_at = now()
    where public.ai_usage.request_count < v_daily_limit
  returning request_count into v_used;
  if v_used is null then
    select request_count into v_used from public.ai_usage where user_id = v_user_id and usage_date = v_today;
    return jsonb_build_object('allowed', false, 'plan_code', v_plan_code, 'used', coalesce(v_used, v_daily_limit),
      'daily_limit', v_daily_limit, 'remaining', 0, 'max_output_tokens', v_max_tokens, 'resets_at', v_reset_at);
  end if;
  return jsonb_build_object('allowed', true, 'plan_code', v_plan_code, 'used', v_used,
    'daily_limit', v_daily_limit, 'remaining', greatest(v_daily_limit - v_used, 0),
    'max_output_tokens', v_max_tokens, 'resets_at', v_reset_at);
end;
$$;
revoke all on function public.consume_ai_quota() from public;
grant execute on function public.consume_ai_quota() to authenticated;
