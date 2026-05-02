// ═══════════════════════════════════════════════════════════════════════
// send-vol3-interest
//
// Sends the Vol III early-interest acknowledgement email.
// Completely isolated from send-registration-email. This function only
// knows about Vol III and the 'vol3-early-interest' template.
//
// Contract:
//   POST /functions/v1/send-vol3-interest
//   body: { registration_id: string }
//
// Behavior:
//   1. Loads the registration row from Supabase.
//   2. Verifies it belongs to the Vol III event (defensive guard).
//   3. Loads the 'vol3-early-interest' template.
//   4. Renders handlebars-lite variables (first_name, plus_one_name, etc.)
//      and the {{#if has_plus_one}}...{{/if}} block.
//   5. Sends via Resend using the same FROM_EMAIL as the rest of the stack.
//   6. Logs the send attempt to public.send_email_log (same audit trail).
// ═══════════════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const VOL3_EVENT_SLUG = "houston-vol-3-sep-2026";
const TEMPLATE_SLUG = "vol3-early-interest";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface ReqBody {
  registration_id?: string;
}

interface Registration {
  id: string;
  event_id: string;
  first_name: string | null;
  last_name: string | null;
  email: string;
  has_plus_one: boolean | null;
  plus_one_first_name: string | null;
  plus_one_last_name: string | null;
}

interface EventRow {
  id: string;
  slug: string;
}

interface Template {
  subject: string;
  body_html: string;
  body_text: string | null;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function looksLikeEmail(v: string | null | undefined): boolean {
  if (!v) return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v.trim());
}

function renderTemplate(tpl: string, vars: Record<string, string>, flags: Record<string, boolean>): string {
  let out = tpl.replace(/{{#if\s+(\w+)}}([\s\S]*?){{\/if}}/g, (_m, key, block) => {
    return flags[key] ? block : "";
  });
  for (const [k, v] of Object.entries(vars)) {
    out = out.replaceAll(`{{${k}}}`, v);
  }
  return out;
}

async function logSendAttempt(
  sb: ReturnType<typeof createClient>,
  payload: {
    registration_id: string | null;
    recipient_email: string;
    template_slug: string;
    recipient_type: string;
    attempt_number: number;
    outcome: "sent" | "failed" | "skipped";
    http_status: number | null;
    resend_email_id: string | null;
    error_phase: string | null;
    error_detail: string | null;
    action_type: string;
    duration_ms: number | null;
  },
) {
  try {
    await sb.from("send_email_log").insert([payload]);
  } catch (err) {
    console.warn("send_email_log insert failed (non-blocking):", err);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
  const FROM_EMAIL = Deno.env.get("FROM_EMAIL") ?? "The Horeca Meetup <events@thehorecastore.com>";

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) return json({ error: "missing_supabase_env" }, 500);
  if (!RESEND_API_KEY) return json({ error: "missing_resend_key" }, 500);

  let body: ReqBody;
  try {
    body = await req.json();
  } catch (_err) {
    return json({ error: "invalid_json" }, 400);
  }

  const registrationId = body.registration_id;
  if (!registrationId) return json({ error: "registration_id_required" }, 400);

  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: reg, error: regErr } = await sb
    .from("registrations")
    .select(
      "id, event_id, first_name, last_name, email, has_plus_one, plus_one_first_name, plus_one_last_name",
    )
    .eq("id", registrationId)
    .single<Registration>();

  if (regErr || !reg) {
    return json({ error: "registration_not_found", detail: regErr?.message }, 404);
  }

  if (!looksLikeEmail(reg.email)) {
    await logSendAttempt(sb, {
      registration_id: reg.id,
      recipient_email: reg.email || "",
      template_slug: TEMPLATE_SLUG,
      recipient_type: "primary",
      attempt_number: 0,
      outcome: "skipped",
      http_status: null,
      resend_email_id: null,
      error_phase: "validation",
      error_detail: "invalid_email_format",
      action_type: "vol3_early_interest",
      duration_ms: null,
    });
    return json({ error: "invalid_email" }, 400);
  }

  const { data: ev, error: evErr } = await sb
    .from("events")
    .select("id, slug")
    .eq("id", reg.event_id)
    .single<EventRow>();

  if (evErr || !ev) return json({ error: "event_not_found" }, 404);
  if (ev.slug !== VOL3_EVENT_SLUG) {
    return json({ error: "wrong_event", expected: VOL3_EVENT_SLUG, got: ev.slug }, 400);
  }

  const { data: tpl, error: tplErr } = await sb
    .from("email_templates")
    .select("subject, body_html, body_text")
    .eq("slug", TEMPLATE_SLUG)
    .eq("is_active", true)
    .single<Template>();

  if (tplErr || !tpl) {
    await logSendAttempt(sb, {
      registration_id: reg.id,
      recipient_email: reg.email,
      template_slug: TEMPLATE_SLUG,
      recipient_type: "primary",
      attempt_number: 0,
      outcome: "failed",
      http_status: null,
      resend_email_id: null,
      error_phase: "template_lookup",
      error_detail: `template_not_found: ${tplErr?.message ?? ""}`,
      action_type: "vol3_early_interest",
      duration_ms: null,
    });
    return json({ error: "template_not_found" }, 500);
  }

  const firstName = (reg.first_name ?? "").trim() || "there";
  const plusOneName = [reg.plus_one_first_name, reg.plus_one_last_name]
    .filter(Boolean)
    .join(" ")
    .trim();
  const hasPlusOne = Boolean(reg.has_plus_one && plusOneName);

  const vars: Record<string, string> = {
    first_name: firstName,
    plus_one_name: plusOneName,
    event_date_long: "Tuesday, September 8, 2026",
    venue_name: "Marriott Energy Corridor",
    venue_address: "Houston, Texas",
  };
  const flags: Record<string, boolean> = { has_plus_one: hasPlusOne };

  const subject = renderTemplate(tpl.subject, vars, flags);
  const html = renderTemplate(tpl.body_html, vars, flags);
  const text = tpl.body_text ? renderTemplate(tpl.body_text, vars, flags) : undefined;

  const resendPayload = {
    from: FROM_EMAIL,
    to: [reg.email],
    subject,
    html,
    text,
    tags: [
      { name: "template", value: TEMPLATE_SLUG },
      { name: "event", value: VOL3_EVENT_SLUG },
      { name: "recipient_type", value: "primary" },
      { name: "action", value: "vol3_early_interest" },
    ],
  };

  let attempt = 0;
  let lastError = "";
  let lastStatus: number | null = null;
  let resendId: string | null = null;
  const t0 = Date.now();

  while (attempt < 3) {
    attempt += 1;
    try {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(resendPayload),
      });
      lastStatus = res.status;
      const raw = await res.text();
      if (res.ok) {
        try {
          const parsed = JSON.parse(raw);
          resendId = parsed?.id ?? null;
        } catch {
          resendId = null;
        }
        await logSendAttempt(sb, {
          registration_id: reg.id,
          recipient_email: reg.email,
          template_slug: TEMPLATE_SLUG,
          recipient_type: "primary",
          attempt_number: attempt,
          outcome: "sent",
          http_status: res.status,
          resend_email_id: resendId,
          error_phase: null,
          error_detail: null,
          action_type: "vol3_early_interest",
          duration_ms: Date.now() - t0,
        });
        return json({ ok: true, resend_id: resendId });
      }
      lastError = raw.slice(0, 500);
      if (res.status !== 429 && res.status < 500) break;
    } catch (err) {
      lastError = err instanceof Error ? err.message : String(err);
    }
    if (attempt < 3) await new Promise((r) => setTimeout(r, 400 * attempt));
  }

  await logSendAttempt(sb, {
    registration_id: reg.id,
    recipient_email: reg.email,
    template_slug: TEMPLATE_SLUG,
    recipient_type: "primary",
    attempt_number: attempt,
    outcome: "failed",
    http_status: lastStatus,
    resend_email_id: null,
    error_phase: "resend_api",
    error_detail: lastError.slice(0, 1000),
    action_type: "vol3_early_interest",
    duration_ms: Date.now() - t0,
  });

  return json({ error: "resend_failed", detail: lastError, status: lastStatus }, 502);
});
