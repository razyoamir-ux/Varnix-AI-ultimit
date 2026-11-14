// Varnix AI authenticated chat proxy.
// Store OPENROUTER_API_KEY only as a Supabase Edge Function secret.
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
  const serverOpenRouterKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!supabaseUrl || !anonKey) return json({ error: "Backend is not configured" }, 503);

  const declaredLength = Number(req.headers.get("content-length") ?? "0");
  if (declaredLength > 128_000) return json({ error: "Request is too large" }, 413);

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return json({ error: "Unauthorized" }, 401);

  try {
    const rawBody = await req.text();
    if (rawBody.length > 128_000) return json({ error: "Request is too large" }, 413);

    let payload: any;
    try {
      payload = JSON.parse(rawBody);
    } catch {
      return json({ error: "Invalid JSON body" }, 400);
    }

    const providers: Record<string, { baseUrl: string }> = {
      openrouter: { baseUrl: "https://openrouter.ai/api/v1" },
      groq: { baseUrl: "https://api.groq.com/openai/v1" },
      gemini: { baseUrl: "https://generativelanguage.googleapis.com/v1beta/openai" },
      mistral: { baseUrl: "https://api.mistral.ai/v1" },
      deepseek: { baseUrl: "https://api.deepseek.com/v1" },
      together: { baseUrl: "https://api.together.ai/v1" },
      fireworks: { baseUrl: "https://api.fireworks.ai/inference/v1" },
      cerebras: { baseUrl: "https://api.cerebras.ai/v1" },
      deepinfra: { baseUrl: "https://api.deepinfra.com/v1/openai" },
      cohere: { baseUrl: "https://api.cohere.ai/compatibility/v1" },
      novita: { baseUrl: "https://api.novita.ai/openai/v1" },
      nvidia: { baseUrl: "https://integrate.api.nvidia.com/v1" },
      xai: { baseUrl: "https://api.x.ai/v1" },
      openai: { baseUrl: "https://api.openai.com/v1" },
      qwen: { baseUrl: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1" },
      zai: { baseUrl: "https://api.z.ai/api/paas/v4" },
      moonshot: { baseUrl: "https://api.moonshot.ai/v1" },
      huggingface: { baseUrl: "https://router.huggingface.co/v1" },
      sambanova: { baseUrl: "https://api.sambanova.ai/v1" },
      siliconflow: { baseUrl: "https://api.siliconflow.com/v1" },
      minimax: { baseUrl: "https://api.minimax.io/v1" },
    };
    const providerId = typeof payload?.provider_id === "string" ? payload.provider_id : "openrouter";
    const provider = providers[providerId];
    if (!provider) return json({ error: "AI provider is not supported" }, 400);
    const suppliedUserKey = providerId === "openrouter" ? payload?.openrouter_api_key : payload?.provider_api_key;
    if (suppliedUserKey !== undefined &&
        (typeof suppliedUserKey !== "string" || suppliedUserKey.trim().length < 8 || suppliedUserKey.length > 512)) {
      return json({ error: "کلید API واردشده معتبر نیست." }, 400);
    }
    const openRouterKey = providerId === "openrouter" ? (suppliedUserKey || serverOpenRouterKey) : suppliedUserKey;
    if (!openRouterKey) {
      return json({ error: "برای این سرویس ابتدا کلید API شخصی خودت را در تنظیمات وارد کن." }, 503);
    }

    const incoming = payload?.messages;
    if (!Array.isArray(incoming) || incoming.length === 0 || incoming.length > 30) {
      return json({ error: "Invalid messages" }, 400);
    }

    const safeMessages: Array<{ role: "user" | "assistant"; content: string }> = [];
    let totalCharacters = 0;
    for (const message of incoming) {
      if (!message || !["user", "assistant"].includes(message.role) ||
          typeof message.content !== "string" || message.content.trim().length === 0) {
        return json({ error: "Invalid message format" }, 400);
      }
      const content = message.content.trim();
      if (content.length > 12_000) return json({ error: "A message is too long" }, 413);
      totalCharacters += content.length;
      safeMessages.push({ role: message.role, content });
    }
    if (totalCharacters > 60_000 || safeMessages[safeMessages.length - 1].role !== "user") {
      return json({ error: "Message history is invalid or too large" }, 400);
    }

    const { data: config, error: configError } = await supabase
      .from("app_config")
      .select("default_model,api_base_url,system_prompt")
      .eq("id", true)
      .maybeSingle();
    if (configError) return json({ error: "Could not load app configuration" }, 503);

    let model = config?.default_model ?? "openrouter/free";
    let systemPrompt = config?.system_prompt ?? "تو یک دستیار هوشمند فارسی‌زبان به نام وارنیکس هستی.";
    if (typeof payload.assistant_id === "string" && payload.assistant_id.length <= 80) {
      const { data: assistant, error: assistantError } = await supabase
        .from("assistants")
        .select("system_prompt,model,is_active")
        .eq("id", payload.assistant_id)
        .maybeSingle();
      if (assistantError || !assistant || !assistant.is_active) {
        return json({ error: "Assistant not found or inactive" }, 404);
      }
      model = assistant.model;
      systemPrompt = assistant.system_prompt;
    }

    const supportMode = payload.support_mode === true;
    if (supportMode && typeof payload.assistant_id === "string") {
      return json({ error: "Support mode cannot select another assistant" }, 400);
    }
    if (supportMode) {
      model = config?.default_model ?? "openrouter/free";
      systemPrompt = `تو «دستیار راهنمای وارنیکس» هستی؛ یک دستیار پشتیبانی اختصاصی داخل اپلیکیشن Varnix AI.
فقط درباره خود اپلیکیشن وارنیکس کمک کن: ثبت‌نام و ورود، تأیید ایمیل، حساب کاربری، تنظیمات، گفتگو با هوش مصنوعی، انتخاب دستیارها، ابزارهای موجود، پلن‌ها، کلید API و OpenRouter، خطاهای برنامه و روش استفاده از قابلیت‌های واقعاً موجود.
همیشه فارسی، صمیمی، روشن و مرحله‌به‌مرحله پاسخ بده. اگر کاربر مبتدی است هر بار فقط قدم بعدی را بگو.
اطلاعات قطعی برنامه را از این موارد بدان: گفتگوها و حساب کاربری به Supabase متصل‌اند؛ پاسخ‌های هوش مصنوعی از طریق سرور و OpenRouter پردازش می‌شوند؛ کلید مدیریتی وارنیکس نباید در اختیار کاربران قرار بگیرد؛ قابلیت کلید اختصاصی OpenRouter در تنظیمات ممکن است به راه‌اندازی سمت سرور نیاز داشته باشد؛ پلن حرفه‌ای تا زمان اتصال و تأیید درگاه پرداخت قابل خرید واقعی نیست.
هرگز وجود قابلیت، اتصال، پرداخت، انتشار، امنیت کامل یا موفقیت عملیاتی را حدس نزن. اگر وضعیت یک قابلیت یا خطا را نمی‌دانی، صادقانه بگو و برای تشخیص، متن کامل خطا یا تصویر صفحه را درخواست کن. برای حل مشکل، ابتدا ساده‌ترین بررسی بی‌خطر را پیشنهاد بده و از کاربر رمز عبور، توکن، کلید API یا اطلاعات محرمانه نخواه.
به موضوعات نامرتبط با پشتیبانی وارنیکس وارد نشو؛ در صورت نیاز مؤدبانه توضیح بده که این بخش مخصوص راهنمای خود برنامه است. قابلیت‌های آموزشی، درس، آزمون یا آکادمی را به‌عنوان امکانات وارنیکس معرفی نکن.`;
    }
    if (typeof payload.model === "string" && payload.model.trim().length > 0 && payload.model.length <= 160) {
      model = payload.model.trim();
    }

    const userInstructions = payload.user_instructions ?? "";
    if (typeof userInstructions !== "string" || userInstructions.length > 2_000) {
      return json({ error: "User instructions are invalid or too long" }, 400);
    }
    if (userInstructions.trim().length > 0) {
      systemPrompt += "\n\nUser preferences supplied by this account (follow when compatible with system and safety rules):\n" + userInstructions.trim();
    }

    if (typeof model !== "string" || model.length > 160 ||
        typeof systemPrompt !== "string" || systemPrompt.length > 14_100) {
      return json({ error: "AI configuration is invalid" }, 503);
    }

    const { data: quota, error: quotaError } = await supabase.rpc("consume_ai_quota");
    if (quotaError || !quota || typeof quota !== "object") {
      return json({ error: "سهمیه حساب بررسی نشد؛ لطفاً کمی بعد دوباره تلاش کن." }, 503);
    }
    if (quota.allowed !== true) {
      return json({
        error: `سهمیه روزانه پلن شما تکمیل شده است (${quota.used}/${quota.daily_limit}). سهمیه در شروع روز UTC بعدی بازنشانی می‌شود.`,
        quota,
      }, 429);
    }

    const upstream = await fetch(new URL(provider.baseUrl + "/chat/completions"), {
      method: "POST",
      headers: {
        "Authorization": "Bearer " + openRouterKey,
        "Content-Type": "application/json",
        "X-Title": "Varnix AI",
      },
      body: JSON.stringify({
        model,
        messages: [{ role: "system", content: systemPrompt }, ...safeMessages],
        temperature: 0.7,
        max_tokens: Math.min(Number(quota.max_output_tokens) || 2048, 8192),
      }),
      signal: AbortSignal.timeout(55_000),
    });

    const responseBody = await upstream.text();
    if (responseBody.length > 1_000_000) return json({ error: "AI response is too large" }, 502);
    return new Response(responseBody, {
      status: upstream.status,
      headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "TimeoutError") {
      return json({ error: "AI provider timed out. Please try again." }, 504);
    }
    return json({ error: "Request could not be processed" }, 400);
  }
});
