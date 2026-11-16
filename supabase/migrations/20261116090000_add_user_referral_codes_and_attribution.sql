alter table public.profiles
  add column if not exists referral_code text
  generated always as (
    'VARNIX-' || upper(substr(replace(id::text, '-', ''), 1, 8))
  ) stored;

alter table public.profiles
  add column if not exists referred_by uuid
  references public.profiles(id) on delete set null;

create unique index if not exists profiles_referral_code_uidx
  on public.profiles (referral_code);

create index if not exists profiles_referred_by_idx
  on public.profiles (referred_by);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $function$
declare
  v_code text;
  v_referrer uuid;
begin
  v_code := upper(trim(coalesce(new.raw_user_meta_data->>'referral_code', '')));

  if v_code <> '' then
    select p.id
      into v_referrer
      from public.profiles p
      where p.referral_code = v_code
        and p.id <> new.id
      limit 1;
  end if;

  insert into public.profiles (id, email, display_name, referred_by)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'display_name', ''),
    v_referrer
  )
  on conflict (id) do nothing;

  return new;
end;
$function$;
