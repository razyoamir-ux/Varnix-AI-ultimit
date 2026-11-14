# تنظیم نهایی تأیید ایمیل وارنیکس

این فایل، قالب فارسی و زیبا برای ایمیل تأیید ثبت‌نام است. برای جلوگیری از برگشت به localhost، باید قالب و Redirect URL در داشبورد Supabase نیز تنظیم شوند.

## ۱) تنظیم Redirect URL

در پروژه Supabase با شناسه `gwhlihrijgpdvcpleodi`:

1. به Authentication → URL Configuration برو.
2. در **Additional Redirect URLs** این آدرس را دقیقاً اضافه کن:

   `com.varnix.ai://login-callback/`

3. برای **Site URL** هم اگر برنامه فقط اپلیکیشن موبایل است، این مقدار را قرار بده:

   `com.varnix.ai://login-callback/`

4. ذخیره کن.

## ۲) شخصی‌سازی ایمیل تأیید

1. به Authentication → Email Templates → Confirm signup برو.
2. Subject را این بگذار:

   `💜 فقط یک قدم تا ورود به وارنیکس!`

3. محتوای بخش Body را با تمام HTML داخل فایل `supabase/templates/confirm-signup.html` جایگزین کن.
4. Save بزن.

**نکته فنی:** لینک دکمه باید از متغیر `{{ .ConfirmationURL }}` استفاده کند. این لینک توسط Supabase ساخته می‌شود و پارامتر بازگشت برنامه را حفظ می‌کند. از `{{ .SiteURL }}` به‌عنوان مقصد مستقیم دکمه استفاده نکن؛ در غیر این صورت ممکن است کاربر به آدرس اشتباه مانند localhost برگردد.

## ۳) تنظیم برنامه

کد ثبت‌نام در اپلیکیشن، `emailRedirectTo: 'com.varnix.ai://login-callback/'` را ارسال می‌کند. Android Manifest نیز همین scheme و host را ثبت کرده است. Supabase Flutter از Deep Link در Android پشتیبانی می‌کند.

## ۴) تست واقعی

پس از ذخیره تنظیمات و نصب APK جدید:
1. با یک ایمیل آزمایشی که قبلاً ثبت‌نام نکرده، حساب بساز.
2. ایمیل Confirm signup را باز کن و دکمه «تأیید ایمیل من» را بزن.
3. باید برنامه Varnix AI باز شود و نشست کاربر فعال گردد؛ نباید صفحه localhost دیده شود.

اگر تأیید ایمیل قبلاً خاموش شده باشد، این ایمیل ارسال نمی‌شود؛ برای ثبت‌نام ایمیلی با تأیید، گزینه Confirm email باید در تنظیمات Auth روشن باشد. ورود با Google مسیر جداگانه‌ای دارد و تأیید ایمیل جدا نمی‌خواهد.
