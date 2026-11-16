import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return Response.json({ error: "Method not allowed" }, { status: 405, headers: cors });
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return Response.json({ error: "ورود به حساب لازم است." }, { status: 401, headers: cors });
  try {
    const body = await req.json();
    const language = body?.language;
    const source = body?.code;
    if (!["python", "java"].includes(language)) return Response.json({ error: "فقط Python و Java پشتیبانی می‌شوند." }, { status: 400, headers: cors });
    if (typeof source !== "string" || source.trim().length === 0 || source.length > 12000) return Response.json({ error: "کد باید بین ۱ تا ۱۲۰۰۰ نویسه باشد." }, { status: 400, headers: cors });
    const filename = language === "python" ? "main.py" : "Main.java";
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 18000);
    let upstream: Response;
    try {
      upstream = await fetch("https://emkc.org/api/v2/piston/execute", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          language, version: "*", files: [{ name: filename, content: source }],
          stdin: typeof body?.stdin === "string" ? body.stdin.slice(0, 4000) : "",
          args: [], compile_timeout: 10000, run_timeout: 5000,
          compile_memory_limit: 128000000, run_memory_limit: 128000000,
        }),
        signal: controller.signal,
      });
    } finally { clearTimeout(timeout); }
    const result = await upstream.json().catch(() => ({}));
    if (!upstream.ok) return Response.json({ error: "سرویس اجرای کد فعلاً پاسخ‌گو نیست." }, { status: 502, headers: cors });
    return Response.json({
      language, compile: result.compile ?? null, run: result.run ?? null,
      output: result.run?.output ?? result.compile?.output ?? "",
      exitCode: result.run?.code ?? result.compile?.code ?? null,
    }, { headers: { ...cors, "Cache-Control": "no-store" } });
  } catch (error) {
    return Response.json({ error: error instanceof Error && error.name === "AbortError" ? "زمان اجرای کد تمام شد." : "اجرای کد ناموفق بود." }, { status: 502, headers: cors });
  }
});