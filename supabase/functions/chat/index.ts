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
  const openRouterKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!supabaseUrl || !anonKey) return json({ error: "Backend is not configured" }, 503);
  if (!openRouterKey) return json({ error: "AI provider is not configured" }, 503);

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

    const userInstructions = payload.user_instructions ?? "";
    if (typeof userInstructions !== "string" || userInstructions.length > 2_000) {
      return json({ error: "User instructions are invalid or too long" }, 400);
    }
    if (userInstructions.trim().length > 0) {
      systemPrompt += "\\n\\nUser preferences supplied by this account (follow when compatible with system and safety rules):\\n" + userInstructions.trim();
    }

    if (typeof model !== "string" || model.length > 160 ||
        typeof systemPrompt !== "string" || systemPrompt.length > 14_100) {
      return json({ error: "AI configuration is invalid" }, 503);
    }

    const baseUrl = new URL(config?.api_base_url ?? "https://openrouter.ai/api/v1");
    // This release supports OpenRouter only. Restrict the host to prevent
    // admin misconfiguration from turning this proxy into an arbitrary fetcher.
    if (baseUrl.protocol !== "https:" || baseUrl.hostname !== "openrouter.ai" ||
        baseUrl.username || baseUrl.password) {
      return json({ error: "Unsupported AI provider URL" }, 503);
    }

    const upstream = await fetch(new URL("/api/v1/chat/completions", baseUrl.origin), {
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
        max_tokens: 2048,
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
