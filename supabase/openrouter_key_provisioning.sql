-- Per-user OpenRouter key provisioning. The plaintext key is never stored here.
create table if not exists public.openrouter_user_keys (
  user_id uuid primary key references auth.users(id) on delete cascade,
  key_hash text,
  last_issued_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.openrouter_user_keys enable row level security;
revoke all on public.openrouter_user_keys from anon, authenticated;
grant all on public.openrouter_user_keys to service_role;

create or replace function public.reserve_openrouter_key_issue(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  reserved boolean := false;
begin
  insert into public.openrouter_user_keys (user_id, last_issued_at)
  values (p_user_id, now())
  on conflict (user_id) do update
    set last_issued_at = now(), updated_at = now()
    where public.openrouter_user_keys.last_issued_at is null
       or public.openrouter_user_keys.last_issued_at < now() - interval '5 minutes'
  returning true into reserved;

  return coalesce(reserved, false);
end;
$$;

revoke all on function public.reserve_openrouter_key_issue(uuid) from public, anon, authenticated;
grant execute on function public.reserve_openrouter_key_issue(uuid) to service_role;
