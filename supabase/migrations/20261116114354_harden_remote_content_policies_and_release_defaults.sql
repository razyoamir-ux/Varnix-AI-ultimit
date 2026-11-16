do $$
declare t text;
begin
  foreach t in array array['content_documents','other_apps','app_releases','tutorials','prompt_templates','addons'] loop
    execute format('drop policy if exists "public read published" on public.%I',t);
    execute format('drop policy if exists "admin manage all" on public.%I',t);
    execute format('revoke all on public.%I from anon',t);
    execute format('grant select,insert,update,delete on public.%I to authenticated',t);
    if t='content_documents' then
      execute 'create policy "read published or admin" on public.content_documents for select to authenticated using (is_published or (select private.varnix_is_admin()))';
    elsif t='other_apps' then
      execute 'create policy "read published or admin" on public.other_apps for select to authenticated using (is_active or (select private.varnix_is_admin()))';
    elsif t='app_releases' then
      execute 'create policy "read published or admin" on public.app_releases for select to authenticated using (is_published or (select private.varnix_is_admin()))';
    elsif t='tutorials' then
      execute 'create policy "read published or admin" on public.tutorials for select to authenticated using (is_published or (select private.varnix_is_admin()))';
    elsif t='prompt_templates' then
      execute 'create policy "read published or admin" on public.prompt_templates for select to authenticated using (is_published or (select private.varnix_is_admin()))';
    else
      execute 'create policy "read published or admin" on public.addons for select to authenticated using (is_enabled or (select private.varnix_is_admin()))';
    end if;
    execute format('create policy "admin insert" on public.%I for insert to authenticated with check ((select private.varnix_is_admin()))',t);
    execute format('create policy "admin update" on public.%I for update to authenticated using ((select private.varnix_is_admin())) with check ((select private.varnix_is_admin()))',t);
    execute format('create policy "admin delete" on public.%I for delete to authenticated using ((select private.varnix_is_admin()))',t);
  end loop;
end $$;

update public.app_config set
  pro_price='189000',
  pro_base_price=189000,
  pro_duration_days=30,
  payment_provider='myket',
  payment_enabled=false,
  ads_enabled=false,
  ad_banner_enabled=false,
  ad_interstitial_enabled=false,
  ad_rewarded_enabled=false,
  free_daily_video_limit=0,
  pro_daily_image_generation_limit=0,
  pro_daily_video_generation_limit=0,
  updated_at=now()
where id=true;

update public.subscription_plans set price_label='۱۸۹٬۰۰۰ تومان',duration_days=30,is_active=true,updated_at=now() where plan_code='pro';
update public.subscription_plans set price_label='۰ تومان',duration_days=30,is_active=true,updated_at=now() where plan_code='free';
