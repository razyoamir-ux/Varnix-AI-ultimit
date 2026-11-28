create unique index if not exists purchases_provider_transaction_unique
  on public.purchases (provider, provider_transaction_id)
  where provider_transaction_id is not null;

create or replace function public.activate_myket_purchase(
  p_user_id uuid,
  p_developer_payload text,
  p_order_id text,
  p_purchase_time timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_purchase public.purchases%rowtype;
  v_expires_at timestamptz;
begin
  if p_user_id is null
     or nullif(trim(p_developer_payload), '') is null
     or nullif(trim(p_order_id), '') is null
     or p_purchase_time is null then
    raise exception 'invalid_purchase_arguments';
  end if;

  select *
    into v_purchase
    from public.purchases
   where provider = 'myket'
     and provider_reference = p_developer_payload
     and user_id = p_user_id
   for update;

  if not found then
    raise exception 'purchase_session_not_found';
  end if;

  if v_purchase.status = 'paid' then
    if v_purchase.provider_transaction_id is distinct from p_order_id then
      raise exception 'purchase_transaction_mismatch';
    end if;

    select plan_expires_at into v_expires_at
      from public.profiles where id = p_user_id;
    return jsonb_build_object('already_processed', true, 'expires_at', v_expires_at);
  end if;

  if v_purchase.status <> 'pending'
     or v_purchase.provider_transaction_id is not null then
    raise exception 'purchase_not_pending';
  end if;

  update public.purchases
     set status = 'paid',
         provider_transaction_id = p_order_id,
         verified_at = now(),
         updated_at = now()
   where id = v_purchase.id;

  update public.profiles
     set plan_code = 'pro',
         plan_expires_at =
           greatest(coalesce(plan_expires_at, p_purchase_time), p_purchase_time)
           + interval '30 days',
         updated_at = now()
   where id = p_user_id
     and role = 'user'
  returning plan_expires_at into v_expires_at;

  if not found then
    raise exception 'profile_not_found_or_not_user';
  end if;

  return jsonb_build_object('already_processed', false, 'expires_at', v_expires_at);
end;
$$;

revoke all on function public.activate_myket_purchase(uuid, text, text, timestamptz) from public, anon, authenticated;
grant execute on function public.activate_myket_purchase(uuid, text, text, timestamptz) to service_role;
