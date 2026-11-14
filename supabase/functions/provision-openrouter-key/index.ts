// Creates a dedicated, spend-capped OpenRouter API key for the authenticated Varnix user.
// OPENROUTER_MANAGEMENT_KEY is a server-only secret and must never be shipped in the APK.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return json({ error: "Unauthorized" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const managementKey = Deno.env.get("OPENROUTER_MANAGEMENT_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: "Supabase function is not configured" }, 503);
  }
  if (!managementKey) {
    return json({ error: "OpenRouter key provisioning is not configured yet" }, 503);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) return json({ error: "Unauthorized" }, 401);

  const service = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let reservationHeld = false;
  const releaseReservation = async () => {
    if (!reservationHeld) return;
    await service.from("openrouter_user_keys")
      .update({ last_issued_at: null })
      .eq("user_id", user.id);
    reservationHeld = false;
  };

  try {
    const { data: reserved, error: reserveError } = await service.rpc(
      "reserve_openrouter_key_issue",
      { p_user_id: user.id },
    );
    if (reserveError) return json({ error: "Could not reserve API key issuance" }, 503);
    if (reserved !== true) {
      return json({ error: "برای جلوگیری از ساخت کلیدهای متعدد، هر ۲۴ ساعت فقط یک‌بار می‌توان کلید جدید ساخت." }, 429);
    }
    reservationHeld = true;

    const { data: previous, error: previousError } = await service
      .from("openrouter_user_keys")
      .select("key_hash")
      .eq("user_id", user.id)
      .maybeSingle();
    if (previousError) {
      await releaseReservation();
      return json({ error: "Could not load previous key metadata" }, 503);
    }

    const configuredLimit = Number(Deno.env.get("OPENROUTER_USER_KEY_LIMIT_USD") ?? "1");
    const limitUsd = Number.isFinite(configuredLimit) && configuredLimit > 0
      ? Math.min(configuredLimit, 10)
      : 1;

    const createResponse = await fetch("https://openrouter.ai/api/v1/keys", {
      method: "POST",
      headers: {
        "Authorization": "Bearer " + managementKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        name: "Varnix user " + user.id.slice(0, 8),
        limit: limitUsd,
        limit_reset: "daily",
      }),
      signal: AbortSignal.timeout(20_000),
    });

    const createBody = await createResponse.json().catch(() => null);
    if (!createResponse.ok) {
      await releaseReservation();
      return json({
        error: createResponse.status === 401 || createResponse.status === 403
          ? "کلید مدیریتی OpenRouter معتبر نیست یا مجوز ساخت کلید ندارد."
          : "OpenRouter نتوانست کلید جدید بسازد.",
      }, 502);
    }

    const created = createBody?.data ?? createBody;
    const userApiKey = created?.key;
    const keyHash = created?.hash;
    if (typeof userApiKey !== "string" || !userApiKey.startsWith("sk-or-") ||
        typeof keyHash !== "string" || keyHash.length < 8) {
      await releaseReservation();
      return json({ error: "OpenRouter پاسخ قابل‌انتظاری برای ساخت کلید نداد." }, 502);
    }

    const { error: saveError } = await service
      .from("openrouter_user_keys")
      .upsert({
        user_id: user.id,
        key_hash: keyHash,
        last_issued_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id" });

    if (saveError) {
      await fetch("https://openrouter.ai/api/v1/keys/" + encodeURIComponent(keyHash), {
        method: "DELETE",
        headers: { "Authorization": "Bearer " + managementKey },
      }).catch(() => undefined);
      await releaseReservation();
      return json({ error: "کلید ساخته شد اما ذخیره امن اطلاعات آن ناموفق بود؛ دوباره تلاش کنید." }, 503);
    }

    // Rotate: invalidate the previous Varnix-issued key after the replacement is safely stored.
    if (typeof previous?.key_hash === "string" && previous.key_hash !== keyHash) {
      await fetch("https://openrouter.ai/api/v1/keys/" + encodeURIComponent(previous.key_hash), {
        method: "DELETE",
        headers: { "Authorization": "Bearer " + managementKey },
      }).catch(() => undefined);
    }

    // The plaintext key is returned exactly once and is never persisted by Varnix.
    return json({ key: userApiKey, limit_usd: limitUsd, one_time: true });
  } catch (error) {
    await releaseReservation();
    if (error instanceof DOMException && error.name === "TimeoutError") {
      return json({ error: "ارتباط با OpenRouter بیش از حد طول کشید؛ دوباره تلاش کنید." }, 504);
    }
    return json({ error: "ساخت کلید API انجام نشد." }, 500);
  }
});
