-- Varnix AI subscription tiers and server-enforced daily AI quotas.
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
  ('free', 'رایگان', 20, 1024, '۰ تومان', 0 + 30, 0),
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
create policy "plans readable by authenticated"
on public.subscription_plans for select to authenticated using (is_active or public.is_admin());

drop policy if exists "admins manage subscription plans" on public.subscription_plans;
create policy "admins manage subscription plans"
on public.subscription_plans for all to authenticated
using (public.is_admin()) with check (public.is_admin());

drop policy if exists "users read own ai usage" on public.ai_usage;
create policy "users read own ai usage"
on public.ai_usage for select to authenticated
using (auth.uid() = user_id or public.is_admin());

grant select on public.subscription_plans to authenticated;
grant select on public.ai_usage to authenticated;

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
  if new_plan_code is not null and new_plan_code not in ('free', 'pro', 'pro_max', 'ultra_max') then
    raise exception 'Invalid plan code';
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

create or replace function public.consume_ai_quota()
returns jsonb
language plpgsql
security definer
set search_path = public
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
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select plan_code, plan_expires_at
    into v_plan_code, v_expires_at
  from public.profiles
  where id = v_user_id;

  if v_plan_code is null then
    v_plan_code := 'free';
  end if;
  if v_plan_code <> 'free' and v_expires_at is not null and v_expires_at <= now() then
    v_plan_code := 'free';
  end if;

  select daily_request_limit, max_output_tokens
    into v_daily_limit, v_max_tokens
  from public.subscription_plans
  where plan_code = v_plan_code and is_active = true;

  if not found then
    v_plan_code := 'free';
    v_daily_limit := 20;
    v_max_tokens := 1024;
  end if;

  insert into public.ai_usage (user_id, usage_date, request_count, updated_at)
  values (v_user_id, v_today, 1, now())
  on conflict (user_id, usage_date) do update
    set request_count = public.ai_usage.request_count + 1,
        updated_at = now()
    where public.ai_usage.request_count < v_daily_limit
  returning request_count into v_used;

  if v_used is null then
    select request_count into v_used
    from public.ai_usage
    where user_id = v_user_id and usage_date = v_today;
    return jsonb_build_object(
      'allowed', false,
      'plan_code', v_plan_code,
      'used', coalesce(v_used, v_daily_limit),
      'daily_limit', v_daily_limit,
      'remaining', 0,
      'max_output_tokens', v_max_tokens,
      'resets_at', v_reset_at
    );
  end if;

  return jsonb_build_object(
    'allowed', true,
    'plan_code', v_plan_code,
    'used', v_used,
    'daily_limit', v_daily_limit,
    'remaining', greatest(v_daily_limit - v_used, 0),
    'max_output_tokens', v_max_tokens,
    'resets_at', v_reset_at
  );
end;
$$;

revoke all on function public.consume_ai_quota() from public;
grant execute on function public.consume_ai_quota() to authenticated;
