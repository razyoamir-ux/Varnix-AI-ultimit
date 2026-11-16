create or replace function public.get_my_referral_count()
returns bigint
language sql
stable
security definer
set search_path = ''
as $function$
  select count(*)::bigint
  from public.profiles p
  where p.referred_by = (select auth.uid());
$function$;

revoke all on function public.get_my_referral_count() from public;
revoke all on function public.get_my_referral_count() from anon;
grant execute on function public.get_my_referral_count() to authenticated;
