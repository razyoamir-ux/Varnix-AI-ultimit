# راه‌اندازی بک‌اند Varnix AI v3

این راهنما را به‌ترتیب انجام دهید. بدون تکمیل این مراحل، APK به سرور متصل نمی‌شود.

## ۱) ساخت پروژه Supabase
1. در Supabase یک پروژه جدید بسازید.
2. از **Project Settings → API** مقدار **Project URL** و **anon/public key** را بردارید.
3. در **Authentication → Providers** ورود با Email را فعال کنید.
4. اگر تأیید ایمیل روشن است، ارسال ایمیل و قالب‌های تأیید را تنظیم کنید.

## ۲) ساخت جداول و سیاست‌های امنیتی
فایل `schema.sql` را کامل در **SQL Editor** اجرا کنید. این فایل جدول‌های کاربران، تنظیمات عمومی، دستیارها، خریدها، گفتگوها و پیام‌ها را می‌سازد و Row Level Security را فعال می‌کند.

نکته: نقش مدیر را از داخل اپلیکیشن نمی‌توان برای خود ارتقا داد. بعد از اینکه حساب مالک در اپ ثبت‌نام کرد، ایمیل همان حساب را پیدا کنید و فقط همان حساب را مدیر کنید. نمونه SQL:

```sql
update public.profiles
set role = 'admin'
where email = 'YOUR_OWNER_EMAIL';
```

جایگزین `YOUR_OWNER_EMAIL` را با ایمیل واقعی مالک کنید و قبل از اجرا مطمئن شوید دقیقاً یک ردیف انتخاب می‌شود.

## ۳) تنظیم تابع هوش مصنوعی
تابع `functions/chat/index.ts` را با نام `chat` در Supabase منتشر کنید. روش پیشنهادی با Supabase CLI:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set OPENROUTER_API_KEY=YOUR_OPENROUTER_API_KEY
supabase functions deploy chat
```

کلید OpenRouter را فقط در Secrets سمت سرور قرار دهید. آن را در GitHub، Flutter، فایل APK یا پیام گفتگو قرار ندهید. این نسخه فعلاً آدرس HTTPS رسمی OpenRouter را می‌پذیرد.

## ۴) تنظیم آدرس بازگشت ایمیل
در **Authentication → URL Configuration → Redirect URLs** این آدرس را اضافه کنید:

`com.varnix.ai://login-callback/`

همچنین مطمئن شوید تأیید ایمیل و بازیابی رمز برای همین redirect مجاز هستند. اگر از لینک تأیید ایمیل استفاده می‌کنید، قالب ایمیل Supabase را متناسب با deep link اپ تنظیم کنید.

## ۵) اتصال GitHub Actions به Supabase
در مخزن GitHub وارد **Settings → Secrets and variables → Actions** شوید و این دو Repository Secret را بسازید:

- `SUPABASE_URL` = Project URL
- `SUPABASE_ANON_KEY` = anon/public key

سپس در **Actions → Build Varnix AI APK** گردش‌کار را اجرا کنید. بعد از موفقیت، Artifact با نام `varnix-ai-apk` قابل دریافت است.

این دو مقدار برای کلاینت هستند؛ کلید `service_role` را هرگز در برنامه یا GitHub Actions build arguments قرار ندهید.

## امکانات بک‌اند
- ورود و ثبت‌نام ایمیلی و پروفایل کاربر
- نقش‌های user و admin
- تنظیمات عمومی قابل تغییر از راه دور
- فهرست دستیارهای قابل مدیریت
- گفتگوها و پیام‌های مختص هر کاربر
- سوابق خرید با وضعیت‌های pending/paid/failed/refunded
- پراکسی احراز هویت‌شده برای درخواست هوش مصنوعی

## مواردی که هنوز کامل نشده‌اند
- اتصال و تأیید خودکار درگاه پرداخت؛ ثبت خرید pending به‌تنهایی پرداخت را تأیید نمی‌کند.
- محدودسازی نرخ درخواست در سطح حساب/پلن و داشبورد مصرف.
- آزمون یکپارچه روی پروژه Supabase واقعی و انتشار نهایی در فروشگاه.

قبل از انتشار عمومی، سیاست‌های RLS، ایمیل‌ها، بکاپ پایگاه داده، محدودیت مصرف و حریم خصوصی را در پروژه واقعی آزمایش کنید.
