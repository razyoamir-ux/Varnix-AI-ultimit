# Varnix AI — نسخه ۳

دستیار هوشمند فارسی‌زبان اندروید با حساب کاربری، همگام‌سازی ابری گفتگوها و تنظیمات مدیریتی سمت سرور.

> وضعیت پروژه: زیرساخت نسخه ۳ در حال توسعه است. برای اجرای کامل، پروژه Supabase باید طبق راهنمای `supabase/README.md` راه‌اندازی شود. تا قبل از تنظیم سرور، برنامه عمداً صفحه راه‌اندازی را نمایش می‌دهد.

## امکانات پیاده‌سازی‌شده در شاخه نسخه ۳
- ورود، ثبت‌نام و بازیابی رمز عبور با ایمیل از طریق Supabase Auth
- جداسازی اطلاعات کاربران با Row Level Security
- ذخیره گفتگوها و پیام‌ها در پایگاه داده ابری
- فهرست دستیارهای فعال و انتخاب دستیار در صفحه گفتگو
- دریافت تنظیمات عمومی و اعلان‌ها از سرور
- پنل مدیریت مبتنی بر نقش admin در پروفایل سرور
- ارسال درخواست هوش مصنوعی از طریق Supabase Edge Function؛ کلید ارائه‌دهنده داخل APK قرار نمی‌گیرد
- رابط فارسی و راست‌چین با تم تیره

## راه‌اندازی بک‌اند
راهنمای کامل در [supabase/README.md](supabase/README.md) قرار دارد. خلاصه:
1. یک پروژه Supabase بسازید.
2. فایل `supabase/schema.sql` را در SQL Editor اجرا کنید.
3. تابع `supabase/functions/chat` را با نام `chat` منتشر کنید.
4. مقدار `OPENROUTER_API_KEY` را فقط در Secrets تابع Edge قرار دهید.
5. پس از ثبت‌نام حساب مالک، نقش همان حساب را در جدول `profiles` به `admin` تغییر دهید.
6. دو مقدار عمومی `SUPABASE_URL` و `SUPABASE_ANON_KEY` را در GitHub Actions Secrets با همین نام‌ها ثبت کنید.

**هرگز** کلید `service_role` یا کلید OpenRouter را در برنامه، مخزن عمومی، فایل‌های Flutter یا پیام‌های گفتگو قرار ندهید.

## ساخت APK با GitHub Actions
1. در مخزن GitHub به مسیر **Settings → Secrets and variables → Actions** بروید.
2. دو Secret با نام‌های `SUPABASE_URL` و `SUPABASE_ANON_KEY` اضافه کنید.
3. از زبانه **Actions** گردش‌کار **Build Varnix AI APK** را اجرا کنید.
4. پس از موفقیت، Artifact با نام `varnix-ai-apk` را از همان اجرای workflow دریافت کنید.

ساخت محلی:
```bash
flutter pub get
flutter analyze
flutter build apk --release \
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

## امنیت و پرداخت
- کلید OpenRouter فقط در Secrets سمت سرور نگهداری می‌شود.
- کلید عمومی Supabase به‌تنهایی مجوز دسترسی به داده‌های کاربران نمی‌دهد؛ سیاست‌های RLS باید فعال بمانند.
- نقش مدیر و پلن کاربران نباید از سمت کلاینت قابل ارتقا باشد.
- ثبت پرداخت در وضعیت `pending` به معنی پرداخت موفق نیست. فعال‌سازی پلن پولی تا زمان پیاده‌سازی و اتصال تأیید پرداخت سمت سرور غیرفعال/دستی باقی می‌ماند.
- برای انتشار در مایکت، سیاست‌های روز مایکت، مجوز کتابخانه‌ها، حریم خصوصی و اطلاعات تماس توسعه‌دهنده را بررسی کنید.

## ساختار اصلی
- `lib/`: برنامه Flutter
- `supabase/schema.sql`: ساختار پایگاه داده و سیاست‌های دسترسی
- `supabase/functions/chat/`: پراکسی امن درخواست‌های هوش مصنوعی
- `.github/workflows/build.yml`: ساخت APK

## شاخه توسعه
`varnix-v3-foundation`
