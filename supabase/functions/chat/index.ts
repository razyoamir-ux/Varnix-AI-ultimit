// Varnix AI chat proxy. Configure OPENROUTER_API_KEY as a Supabase secret.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: cors });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const openRouterKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!openRouterKey) return Response.json({ error: "AI provider is not configured" }, { status: 503, headers: cors });

  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } });
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return Response.json({ error: "Unauthorized" }, { status: 401, headers: cors });

  try {
    const payload = await req.json();
    const messages = Array.isArray(payload.messages) ? payload.messages : [];
    if (!messages.length || messages.length > 40) return Response.json({ error: "Invalid messages" }, { status: 400, headers: cors });

    const { data: config } = await supabase.from("app_config").select("default_model,api_base_url,system_prompt").eq("id", true).maybeSingle();
    let model = config?.default_model ?? "openrouter/free";
    let systemPrompt = config?.system_prompt ?? "You are Varnix AI. Reply in Persian when appropriate.";
    if (typeof payload.assistant_id === "string" && payload.assistant_id.length < 80) {
      const { data: assistant } = await supabase
        .from("assistants")
        .select("system_prompt,model,is_active")
        .eq("id", payload.assistant_id)
        .maybeSingle();
      if (!assistant || !assistant.is_active) {
        return Response.json({ error: "Assistant not found or inactive" }, { status: 404, headers: cors });
      }
      model = assistant.model;
      systemPrompt = assistant.system_prompt;
    }
    const safeMessages = messages
      .filter((m: any) => m && ["user", "assistant"].includes(m.role) && typeof m.content === "string")
      .map((m: any) => ({ role: m.role, content: m.content.slice(0, 16000) }));
    if (!safeMessages.length) return Response.json({ error: "No valid messages" }, { status: 400, headers: cors });

    const base = (config?.api_base_url ?? "https://openrouter.ai/api/v1").replace(/\/$/, "");
    const upstream = await fetch(base + "/chat/completions", {
      method: "POST",
      headers: { "Authorization": "Bearer " + openRouterKey, "Content-Type": "application/json", "X-Title": "Varnix AI" },
      body: JSON.stringify({
        model,
        messages: [{ role: "system", content: systemPrompt }, ...safeMessages],
        temperature: 0.7,
        max_tokens: 2048,
      }),
    });
    const body = await upstream.text();
    return new Response(body, { status: upstream.status, headers: { ...cors, "Content-Type": "application/json" } });
  } catch (_error) {
    return Response.json({ error: "Request could not be processed" }, { status: 400, headers: cors });
  }
});
