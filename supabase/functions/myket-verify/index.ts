import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });

const PACKAGE_NAME = "com.varnix.ai.ultimateplus";
const PRODUCT_ID = "varnix_pro_30days_sub";
const SUBSCRIPTION_DAYS = 30;
const encoder = new TextEncoder();

function decodeBase64(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/").replace(/\s/g, "");
  const binary = atob(normalized);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function verifyMyketSignature(originalJson: string, signature: string): Promise<boolean> {
  const configuredKey = Deno.env.get("MYKET_RSA_KEY") ?? "";
  if (!configuredKey.trim()) throw new Error("MYKET_RSA_KEY is not configured");

  const base64Key = configuredKey
    .replace(/-----BEGIN PUBLIC KEY-----/g, "")
    .replace(/-----END PUBLIC KEY-----/g, "")
    .replace(/\s/g, "");
  const key = await crypto.subtle.importKey(
    "spki",
    decodeBase64(base64Key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-1" },
    false,
    ["verify"],
  );
  return await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    decodeBase64(signature),
    encoder.encode(originalJson),
  );
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return json({ error: "ابتدا وارد حساب شوید." }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: "تنظیمات سرور کامل نیست." }, 503);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user || !user.email_confirmed_at) {
    return json({ error: "حساب کاربری تأییدشده لازم است." }, 401);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let body: Record<string, unknown>;
  try {
    const raw = await req.text();
    if (raw.length > 24_000) return json({ error: "درخواست بیش از حد بزرگ است." }, 413);
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("invalid");
    body = parsed as Record<string, unknown>;
  } catch {
    return json({ error: "درخواست نامعتبر است." }, 400);
  }

  if (body.action === "create") {
    const developerPayload = crypto.randomUUID();
    const { error } = await admin.from("purchases").insert({
      user_id: user.id,
      plan_code: "pro",
      amount: 0,
      currency: "IRR",
      provider: "myket",
      provider_reference: developerPayload,
      status: "pending",
    });
    if (error) {
      console.error("myket_purchase_session_create_failed", error.message);
      return json({ error: "ساخت درخواست خرید انجام نشد. دوباره تلاش کنید." }, 500);
    }
    return json({ developer_payload: developerPayload });
  }

  if (body.action !== "verify") return json({ error: "عملیات نامعتبر است." }, 400);

  const originalJson = typeof body.original_json === "string" ? body.original_json : "";
  const signature = typeof body.signature === "string" ? body.signature : "";
  if (!originalJson || originalJson.length > 16_000 || !signature || signature.length > 4_000) {
    return json({ error: "رسید خرید ناقص یا نامعتبر است." }, 400);
  }

  let receipt: Record<string, unknown>;
  try {
    receipt = JSON.parse(originalJson);
    if (!receipt || typeof receipt !== "object" || Array.isArray(receipt)) throw new Error("invalid");
  } catch {
    return json({ error: "ساختار رسید مایکت معتبر نیست." }, 400);
  }

  let signatureValid = false;
  try {
    signatureValid = await verifyMyketSignature(originalJson, signature);
  } catch (error) {
    console.error("myket_signature_verification_error", String(error));
    return json({ error: "اعتبارسنجی امضای مایکت انجام نشد." }, 503);
  }
  if (!signatureValid) return json({ error: "امضای رسید مایکت معتبر نیست." }, 403);

  const packageName = String(receipt.packageName ?? "");
  const productId = String(receipt.productId ?? receipt.sku ?? "");
  const purchaseState = Number(receipt.purchaseState);
  const developerPayload = String(receipt.developerPayload ?? "");
  const orderId = String(receipt.orderId ?? "");
  const purchaseTimeMs = Number(receipt.purchaseTime);
  const purchaseToken = String(receipt.purchaseToken ?? receipt.token ?? "");

  if (
    packageName !== PACKAGE_NAME ||
    productId !== PRODUCT_ID ||
    purchaseState !== 0 ||
    !developerPayload ||
    !orderId ||
    !purchaseToken ||
    !Number.isFinite(purchaseTimeMs) ||
    purchaseTimeMs <= 0 ||
    purchaseTimeMs > Date.now() + 5 * 60 * 1000
  ) {
    return json({ error: "مشخصات رسید با محصول وارنیکس مطابقت ندارد." }, 403);
  }

  const { data: purchase, error: purchaseError } = await admin
    .from("purchases")
    .select("id,status,provider_transaction_id")
    .eq("provider", "myket")
    .eq("provider_reference", developerPayload)
    .eq("user_id", user.id)
    .maybeSingle();

  if (purchaseError || !purchase) {
    return json({ error: "این رسید به درخواست خرید این حساب متصل نیست." }, 403);
  }

  if (purchase.status === "paid") {
    if (purchase.provider_transaction_id !== orderId) {
      return json({ error: "این رسید قبلاً با شناسه دیگری ثبت شده است." }, 409);
    }
    const { data: profile } = await admin
      .from("profiles")
      .select("plan_code,plan_expires_at")
      .eq("id", user.id)
      .maybeSingle();
    const expiry = profile?.plan_expires_at ? new Date(profile.plan_expires_at).getTime() : 0;
    return json({
      verified: true,
      active: profile?.plan_code === "pro" && expiry > Date.now(),
      expires_at: profile?.plan_expires_at ?? null,
      already_processed: true,
    });
  }

  if (purchase.status !== "pending") return json({ error: "درخواست خرید دیگر معتبر نیست." }, 409);

  const purchaseTime = new Date(purchaseTimeMs);
  const singlePurchaseExpiry = purchaseTime.getTime() + SUBSCRIPTION_DAYS * 24 * 60 * 60 * 1000;
  if (singlePurchaseExpiry <= Date.now()) {
    await admin.from("purchases").update({
      status: "failed",
      updated_at: new Date().toISOString(),
    }).eq("id", purchase.id).eq("status", "pending");
    return json({ verified: true, active: false, message: "مدت این خرید به پایان رسیده است." });
  }

  const { data: activation, error: activationError } = await admin.rpc("activate_myket_purchase", {
    p_user_id: user.id,
    p_developer_payload: developerPayload,
    p_order_id: orderId,
    p_purchase_time: purchaseTime.toISOString(),
  });

  if (activationError) {
    console.error("myket_purchase_activation_failed", activationError.message);
    return json({ error: "خرید تأیید شد اما فعال‌سازی اشتراک کامل نشد؛ با پشتیبانی تماس بگیرید." }, 503);
  }

  const expiresAt = activation?.expires_at ?? null;
  return json({
    verified: true,
    active: Boolean(expiresAt && new Date(expiresAt).getTime() > Date.now()),
    expires_at: expiresAt,
    already_processed: activation?.already_processed === true,
  });
});
