create schema if not exists private;
create or replace function private.varnix_is_admin() returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'); $$;
revoke all on function private.varnix_is_admin() from public;
grant usage on schema private to authenticated;
grant execute on function private.varnix_is_admin() to authenticated;
create table if not exists public.content_documents(id uuid primary key default gen_random_uuid(),slug text not null unique check(slug in ('about','terms','privacy')),title text not null,body text not null default '',version text not null default '1.0',updated_at timestamptz not null default now(),is_published boolean not null default true);
create table if not exists public.other_apps(id uuid primary key default gen_random_uuid(),name text not null,slug text not null unique,description text not null default '',icon_url text,store_url text,status text not null default 'coming_soon' check(status in ('coming_soon','published')),sort_order integer not null default 0,is_active boolean not null default true,updated_at timestamptz not null default now());
create table if not exists public.app_releases(id uuid primary key default gen_random_uuid(),version text not null unique,build_number integer not null default 0,title text not null,notes text not null default '',download_url text,is_mandatory boolean not null default false,min_supported_version text,is_published boolean not null default false,published_at timestamptz,created_at timestamptz not null default now());
create table if not exists public.tutorials(id uuid primary key default gen_random_uuid(),title text not null,category text not null default 'عمومی',body text not null default '',image_url text,video_url text,sort_order integer not null default 0,is_published boolean not null default false,updated_at timestamptz not null default now());
create table if not exists public.prompt_templates(id uuid primary key default gen_random_uuid(),title text not null,category text not null default 'عمومی',prompt text not null,is_published boolean not null default false,sort_order integer not null default 0,updated_at timestamptz not null default now());
create table if not exists public.addons(id uuid primary key default gen_random_uuid(),slug text not null unique,name text not null,description text not null default '',icon text not null default 'extension',capability_type text not null check(capability_type in ('feature_flag','remote_content','external_link')),config jsonb not null default '{}'::jsonb,min_app_version text,requires_pro boolean not null default false,is_enabled boolean not null default false,sort_order integer not null default 0,updated_at timestamptz not null default now());
do $$ declare t text; begin foreach t in array array['content_documents','other_apps','app_releases','tutorials','prompt_templates','addons'] loop
execute format('alter table public.%I enable row level security',t); execute format('grant select on public.%I to anon,authenticated',t); execute format('grant insert,update,delete on public.%I to authenticated',t);
execute format('drop policy if exists "public read published" on public.%I',t); execute format('drop policy if exists "admin manage all" on public.%I',t);
if t='content_documents' then execute 'create policy "public read published" on public.content_documents for select to anon,authenticated using(is_published)';
elsif t='other_apps' then execute 'create policy "public read published" on public.other_apps for select to anon,authenticated using(is_active)';
elsif t='app_releases' then execute 'create policy "public read published" on public.app_releases for select to anon,authenticated using(is_published)';
elsif t in ('tutorials','prompt_templates') then execute format('create policy "public read published" on public.%I for select to anon,authenticated using(is_published)',t);
else execute 'create policy "public read published" on public.addons for select to anon,authenticated using(is_enabled)'; end if;
execute format('create policy "admin manage all" on public.%I for all to authenticated using((select private.varnix_is_admin())) with check((select private.varnix_is_admin()))',t);
end loop; end $$;
insert into public.content_documents(slug,title,body,version,is_published) values
('about','درباره وارنیکس','وارنیکس (Varnix AI) یک دستیار هوشمند با هدف ساده‌تر کردن کارهای روزمره، برنامه‌نویسی، یادگیری و خلاقیت است.\n\nسازنده و توسعه‌دهنده این برنامه: امیر عباس الماسی','1.0',true),
('terms','شرایط و قوانین استفاده از Varnix AI','۱. استفاده از برنامه برای کارهای مجاز است و کاربر باید قوانین محل زندگی خود را رعایت کند.\n\n۲. مسئولیت حفظ امنیت حساب بر عهده کاربر است.\n\n۳. پاسخ‌های هوش مصنوعی ممکن است اشتباه یا قدیمی باشند؛ اطلاعات مهم را بررسی کنید.\n\n۴. هزینه‌ها و قوانین سرویس‌های خارجی و کلید API شخصی بر عهده کاربر است.\n\n۵. فعال‌سازی اشتراک فقط پس از تأیید معتبر پرداخت انجام می‌شود.\n\n۶. اطلاعات حساس و غیرضروری را در گفتگوها وارد نکنید.\n\n۷. امکانات و قوانین ممکن است به‌روزرسانی شوند و تغییرات مهم در برنامه اعلام می‌شود.\n\n۸. در صورت سوءاستفاده، دسترسی ممکن است محدود شود.\n\n۹. ادامه استفاده پس از نمایش نسخه جدید قوانین به معنی پذیرش آن است.\n\nاین متن پیش‌نویس است و پیش از انتشار عمومی باید از نظر حقوقی بررسی شود.','1.0',true) on conflict(slug) do nothing;

-- Starter content for the online learning and prompt library.
insert into public.tutorials(title,category,body,sort_order,is_published)
select v.title,v.category,v.body,v.sort_order,true
from (values
('شروع کار با وارنیکس','شروع سریع','۱. وارد حساب خود شو.
۲. از بخش تنظیمات، سرویس و مدل هوش مصنوعی را انتخاب کن.
۳. کلید API خودت را فقط در بخش امن تنظیمات وارد کن و آن را با دیگران به اشتراک نگذار.
۴. برای شروع، یک پیام ساده در گفتگوی هوشمند بنویس.',1),
('ساخت دستیار شخصی','دستیارها','از بخش دستیارهای هوشمند، گزینه دستیار شخصی را بزن. نام، توضیح و دستورالعمل نقش دستیار را وارد کن. برای مثال می‌توانی دستیار برنامه‌نویسی، مترجم یا مربی مطالعه بسازی. دستورالعمل دستیار به‌عنوان پیام سیستمی برای مدل ارسال می‌شود.',2),
('اجرای کد در آزمایشگاه','برنامه‌نویسی','در آزمایشگاه کدنویسی زبان Python یا Java را انتخاب کن، کد را بنویس و اجرا را بزن. ورودی برنامه را در قسمت ورودی استاندارد وارد کن. اجرای ابری موقتی است؛ فایل‌ها و بسته‌های نصب‌شده بین اجراها تضمین نمی‌شوند. پروژه‌های مهم را در بخش پروژه‌های من ذخیره کن.',3)
) as v(title,category,body,sort_order)
where not exists(select 1 from public.tutorials t where t.title=v.title);

insert into public.prompt_templates(title,category,prompt,sort_order,is_published)
select v.title,v.category,v.prompt,v.sort_order,true
from (values
('توضیح ساده یک موضوع','یادگیری','موضوع «[موضوع]» را از پایه و به زبان ساده توضیح بده. مثال کاربردی بزن، اصطلاحات تخصصی را تعریف کن و در پایان سه سؤال برای سنجش یادگیری من مطرح کن.',1),
('برنامه‌نویس همراه','برنامه‌نویسی','مثل یک برنامه‌نویس باتجربه کمکم کن. ابتدا نیازمندی‌ها را روشن کن، سپس راه‌حل مرحله‌ای بده. کد را خوانا و امن بنویس و خطاهای احتمالی و روش تست را توضیح بده. مسئله من: [شرح مسئله]',2),
('ایده‌پردازی محتوا','تولید محتوا','برای موضوع [موضوع] ده ایده خلاقانه و قابل اجرا پیشنهاد بده. برای هر ایده عنوان، مخاطب هدف، قالب محتوا و مراحل اجرا را بنویس.',3),
('برنامه‌ریزی مطالعه','برنامه‌ریزی','برای هدف [هدف] و زمان روزانه [مدت] یک برنامه مطالعه واقع‌بینانه طراحی کن. مرور، استراحت و آزمون کوتاه را هم در برنامه قرار بده.',4),
('بازنویسی حرفه‌ای متن','نوشتن','متن زیر را روان، دقیق و حرفه‌ای بازنویسی کن. معنی اصلی و لحن موردنظر را حفظ کن و از افزودن اطلاعاتی که در متن نیست خودداری کن:
[متن]',5),
('بررسی امنیت کد','برنامه‌نویسی','کد زیر را از نظر باگ، کارایی و امنیت بررسی کن. برای هر مشکل شدت، دلیل و راه اصلاح را بنویس و در پایان نسخه اصلاح‌شده ارائه بده:
[کد]',6)
) as v(title,category,prompt,sort_order)
where not exists(select 1 from public.prompt_templates p where p.title=v.title);

insert into public.addons(slug,name,description,icon,capability_type,config,is_enabled,sort_order)
values
('welcome-guide','راهنمای شروع','راهنمای شروع سریع و نکته‌های اولیه وارنیکس.','school','remote_content','{"body":"برای شروع، ابتدا حساب خود را بساز، سپس در تنظیمات مدل و کلید API خود را وارد کن. هرگز کلید API را در گفتگو یا برای افراد دیگر ارسال نکن."}'::jsonb,false,1),
('help-center','مرکز راهنما','پیوند به صفحه راهنمای رسمی وارنیکس.','help','external_link','{"url":"https://example.com"}'::jsonb,false,2),
('beta-tools','ابزارهای آزمایشی','کلید نمایشی برای فعال‌سازی قابلیت‌های آزمایشی در نسخه‌های آینده.','science','feature_flag','{"flag":"beta_tools"}'::jsonb,false,3)
on conflict(slug) do nothing;


insert into public.content_documents(slug,title,body,version,is_published) values
('privacy','حریم خصوصی وارنیکس', 'حریم خصوصی Varnix AI

این صفحه توضیح می‌دهد که برنامه برای ارائه خدمات چه نوع اطلاعاتی را ممکن است پردازش کند. این متن اطلاع‌رسانی اولیه است و ناشر باید پیش از انتشار عمومی، اطلاعات تماس رسمی، جزئیات دقیق نگهداری داده‌ها و الزامات قانونی محل عرضه را تکمیل و بررسی کند.

۱. اطلاعات حساب: شناسه حساب، نشانی ایمیل، نام نمایشی و اطلاعات وضعیت اشتراک برای ایجاد و مدیریت حساب استفاده می‌شوند.

۲. گفتگوها و محتوای ارسالی: پیام‌ها و تاریخچه گفتگو ممکن است برای ارائه قابلیت همگام‌سازی در پایگاه داده برنامه ذخیره شوند. فایل‌ها یا تصاویر فقط در صورت انتخاب و ارسال توسط کاربر برای پردازش دریافت می‌شوند.

۳. پردازش هوش مصنوعی: برای تولید پاسخ، محتوای لازم از درخواست کاربر به ارائه‌دهنده مدل هوش مصنوعی انتخاب‌شده ارسال می‌شود. پردازش و نگهداری احتمالی داده نزد آن ارائه‌دهنده تابع سیاست حریم خصوصی و شرایط همان ارائه‌دهنده است.

۴. فایل‌ها: فضای ذخیره‌سازی رسانه وارنیکس خصوصی پیکربندی شده است و دسترسی به فایل‌های حساب باید بر اساس مجوزهای همان حساب انجام شود.

۵. خرید و اشتراک: اطلاعات سفارش، مبلغ، وضعیت پرداخت و شناسه پیگیری ممکن است برای فعال‌سازی و پشتیبانی اشتراک ذخیره شوند. اطلاعات کامل کارت بانکی نباید در برنامه ذخیره شود و توسط درگاه یا فروشگاه پرداخت پردازش می‌شود.

۶. نگهداری و امنیت: برنامه از احراز هویت، کنترل دسترسی و سیاست‌های امنیتی پایگاه داده برای حفاظت از اطلاعات استفاده می‌کند. هیچ سامانه‌ای امنیت مطلق ندارد؛ اطلاعات حساس و غیرضروری را در گفتگوها ارسال نکنید.

۷. حقوق کاربر: برای درخواست بررسی، اصلاح یا حذف حساب و داده‌های مرتبط، از راه ارتباطی رسمی ناشر که در صفحه فروشگاه یا کانال رسمی برنامه درج می‌شود استفاده کنید. ناشر باید راه ارتباطی و زمان‌بندی رسیدگی را پیش از انتشار تکمیل کند.

۸. تغییرات: نسخه به‌روزشده این متن از طریق برنامه منتشر می‌شود.

توجه: این متن پیش‌نویس است و تا تکمیل اطلاعات تماس ناشر و بررسی حقوقی، نباید به‌عنوان سیاست نهایی و تأییدشده تلقی شود.', '1.0', true)
on conflict(slug) do nothing;
