import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });

function page(message: string, success: boolean) {
  return new Response(`<!doctype html><html lang="fa" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>پرداخت وارنیکس</title><body style="font-family:sans-serif;background:#100d1d;color:white;display:grid;place-items:center;min-height:90vh;text-align:center"><main><h2>${success ? "پرداخت موفق بود" : "پرداخت ناموفق بود"}</h2><p>${message}</p><p>به برنامه وارنیکس برگردید و وضعیت اشتراک را تازه‌سازی کنید.</p></main></body></html>`, {
    status: 200, headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const url = new URL(req.url);
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const apiKey = Deno.env.get("NEXTPAY_API_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey || !apiKey) {
    return json({ error: "درگاه هنوز توسط مالک پیکربندی نشده است." }, 503);
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // NextPay redirects here with GET parameters after the customer leaves the bank.
  if (req.method === "GET") {
    const transId = url.searchParams.get("trans_id") ?? "";
    const orderId = url.searchParams.get("order_id") ?? "";
    if (!transId || !orderId) return page("اطلاعات بازگشت پرداخت ناقص است.", false);

    const { data: purchase, error } = await admin.from("purchases")
      .select("id,user_id,plan_code,amount,status,provider_transaction_id,provider_reference")
      .eq("provider", "nextpay").eq("provider_reference", orderId).maybeSingle();

    if (error || !purchase || purchase.provider_transaction_id !== transId) {
      return page("سفارش پرداخت پیدا نشد یا معتبر نیست.", false);
    }
    if (purchase.status === "paid") return page("اشتراک شما قبلاً فعال شده است.", true);

    const verifyBody = new URLSearchParams({
      api_key: apiKey,
      trans_id: transId,
      amount: String(Math.round(Number(purchase.amount))),
      currency: "IRT",
    });
    let verification: any;
    try {
      const response = await fetch("https://nextpay.org/nx/gateway/verify", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: verifyBody,
        signal: AbortSignal.timeout(15000),
      });
      verification = await response.json();
    } catch {
      return page("استعلام از بانک انجام نشد. لطفاً با پشتیبانی تماس بگیرید.", false);
    }

    const paid = Number(verification?.code) === 0 &&
      Number(verification?.amount) === Math.round(Number(purchase.amount)) &&
      String(verification?.order_id ?? orderId) === orderId;

    if (!paid) {
      await admin.from("purchases").update({ status: "failed", updated_at: new Date().toISOString() })
        .eq("id", purchase.id).neq("status", "paid");
      return page("تراکنش توسط درگاه تأیید نشد.", false);
    }

    const { data: config } = await admin.from("app_config")
      .select("pro_duration_days").eq("id", true).maybeSingle();
    const days = Math.min(Math.max(Number(config?.pro_duration_days) || 30, 1), 3650);
    const expiresAt = new Date(Date.now() + days * 86400000).toISOString();

    const { error: updatePurchaseError } = await admin.from("purchases")
      .update({ status: "paid", verified_at: new Date().toISOString(), updated_at: new Date().toISOString() })
      .eq("id", purchase.id).neq("status", "paid");
    if (updatePurchaseError) return page("پرداخت تأیید شد اما ثبت اشتراک کامل نشد؛ با پشتیبانی تماس بگیرید.", false);

    const { error: profileError } = await admin.from("profiles").update({
      plan_code: purchase.plan_code,
      plan_expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    }).eq("id", purchase.user_id);
    if (profileError) return page("پرداخت تأیید شد اما فعال‌سازی اشتراک کامل نشد؛ با پشتیبانی تماس بگیرید.", false);

    return page("اشتراک وارنیکس شما فعال شد.", true);
  }

  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return json({ error: "ابتدا وارد حساب شوید." }, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) return json({ error: "نشست کاربری معتبر نیست." }, 401);

  const { data: config, error: configError } = await admin.from("app_config")
    .select("pro_price,pro_duration_days,payment_enabled").eq("id", true).maybeSingle();
  if (configError || !config || config.payment_enabled !== true) {
    return json({ error: "پرداخت آنلاین فعلاً غیرفعال است." }, 503);
  }
  const digits = String(config.pro_price ?? "").replace(/[^0-9]/g, "");
  const amount = Number(digits);
  if (!Number.isSafeInteger(amount) || amount < 1000 || amount > 500000000) {
    return json({ error: "قیمت اشتراک در پنل مالک معتبر تنظیم نشده است." }, 400);
  }

  const orderId = crypto.randomUUID();
  const callbackUri = `${supabaseUrl}/functions/v1/nextpay-payment`;
  const tokenBody = new URLSearchParams({
    api_key: apiKey,
    order_id: orderId,
    amount: String(amount),
    callback_uri: callbackUri,
    currency: "IRT",
    payer_desc: "خرید اشتراک وارنیکس",
  });

  let tokenResult: any;
  try {
    const response = await fetch("https://nextpay.org/nx/gateway/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: tokenBody,
      signal: AbortSignal.timeout(15000),
    });
    tokenResult = await response.json();
  } catch {
    return json({ error: "اتصال به درگاه نکست‌پی برقرار نشد." }, 502);
  }

  if (Number(tokenResult?.code) !== -1 || typeof tokenResult?.trans_id !== "string") {
    return json({ error: "درگاه نتوانست تراکنش را ایجاد کند.", gateway_code: tokenResult?.code ?? null }, 502);
  }

  const { error: insertError } = await admin.from("purchases").insert({
    user_id: user.id,
    plan_code: "pro",
    amount,
    currency: "IRT",
    provider: "nextpay",
    provider_reference: orderId,
    provider_transaction_id: tokenResult.trans_id,
    status: "pending",
  });
  if (insertError) return json({ error: "ثبت سفارش در سرور ناموفق بود." }, 500);

  return json({
    payment_url: `https://nextpay.org/nx/gateway/payment/${encodeURIComponent(tokenResult.trans_id)}`,
    order_id: orderId,
  });
});
