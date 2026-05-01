/**
 * resend-webhook
 *
 * Receives engagement event webhooks from Resend (sent/delivered/opened/
 * clicked/bounced/complained/delivery_delayed), verifies the svix signature,
 * inserts one row per event into public.email_events, and recomputes the
 * per-registration aggregate JSONB on public.registrations.email_engagement.
 *
 * PRD v2.0 FINAL · Section 8.1.
 *
 * Deploy:
 *   supabase functions deploy resend-webhook --no-verify-jwt
 *
 * Required secret:
 *   RESEND_WEBHOOK_SECRET  (from Resend dashboard → Webhooks → whsec_...)
 *
 * CRITICAL: We always acknowledge with 200 OK on internal errors so Resend
 * does not aggressively retry and cause duplicate events.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { Webhook } from "https://esm.sh/svix@1.15.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, svix-id, svix-timestamp, svix-signature",
};

type ResendEventType =
  | "email.sent"
  | "email.delivered"
  | "email.opened"
  | "email.clicked"
  | "email.bounced"
  | "email.complained"
  | "email.delivery_delayed";

type ResendTag = { name: string; value: string };

interface ResendEvent {
  type: ResendEventType;
  created_at: string;
  data: {
    email_id?: string;
    created_at?: string;
    from?: string;
    to?: string[] | string;
    subject?: string;
    tags?: ResendTag[] | Record<string, string>;
    click?: {
      link?: string;
      ipAddress?: string;
      userAgent?: string;
      timestamp?: string;
      city?: string;
      country?: string;
    };
    open?: {
      ipAddress?: string;
      userAgent?: string;
      timestamp?: string;
      city?: string;
      country?: string;
    };
    bounce?: {
      type?: string;
      message?: string;
    };
  };
}

/** Short event slug written to email_events.event_type */
function shortEvent(t: string): string {
  const last = t.split(".").pop() || t;
  return last === "delivery_delayed" ? "delivery_delayed" : last;
}

/** Tags on Resend payloads may arrive as array or plain object. Normalise. */
function tagsAsMap(
  tags: ResendTag[] | Record<string, string> | undefined,
): Record<string, string> {
  if (!tags) return {};
  if (Array.isArray(tags)) {
    const out: Record<string, string> = {};
    for (const t of tags) {
      if (t && typeof t.name === "string") out[t.name] = String(t.value ?? "");
    }
    return out;
  }
  return tags as Record<string, string>;
}

/** UUID check to avoid DB casting errors from accidentally-tagged non-uuid values. */
function isUuid(v: unknown): v is string {
  return typeof v === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
}

function firstEmail(to: string[] | string | undefined): string | null {
  if (!to) return null;
  if (Array.isArray(to)) return to[0] ?? null;
  return String(to);
}

function calendarLinkMatch(url: string | null | undefined): boolean {
  if (!url) return false;
  const u = url.toLowerCase();
  return (
    u.includes("calendar.google.com") ||
    u.includes("/calendar.html") ||
    u.endsWith(".ics") ||
    u.includes("calendar.ics")
  );
}

/** Recompute the email_engagement JSONB entry for (registration_id, slug). */
async function recomputeEngagement(
  supabase: ReturnType<typeof createClient>,
  registrationId: string,
  slug: string,
) {
  const { data: events, error: evErr } = await supabase
    .from("email_events")
    .select(
      "event_type, link_url, ip_address, user_agent, city, occurred_at",
    )
    .eq("registration_id", registrationId)
    .eq("email_template_slug", slug);

  if (evErr) {
    console.error("[resend-webhook] recompute fetch", evErr);
    return;
  }

  const rows = events || [];
  let delivered = false;
  let bounced = false;
  let opened = false;
  let openCount = 0;
  let clickCount = 0;
  let calendarAdded = false;
  let sentAt: string | null = null;
  let firstOpenedAt: string | null = null;
  let lastOpenedAt: string | null = null;
  const cities = new Set<string>();
  const ips = new Set<string>();
  const uas = new Set<string>();

  for (const r of rows as Array<Record<string, unknown>>) {
    const et = String(r.event_type || "");
    const oc = r.occurred_at ? String(r.occurred_at) : null;
    if (et === "sent") {
      if (!sentAt || (oc && oc < sentAt)) sentAt = oc;
    } else if (et === "delivered") {
      delivered = true;
    } else if (et === "bounced" || et === "complained") {
      bounced = true;
    } else if (et === "opened") {
      opened = true;
      openCount += 1;
      if (!firstOpenedAt || (oc && oc < firstOpenedAt)) firstOpenedAt = oc;
      if (!lastOpenedAt || (oc && oc > lastOpenedAt)) lastOpenedAt = oc;
      if (r.city) cities.add(String(r.city));
      if (r.ip_address) ips.add(String(r.ip_address));
      if (r.user_agent) uas.add(String(r.user_agent));
    } else if (et === "clicked") {
      clickCount += 1;
      if (calendarLinkMatch(r.link_url as string | null)) calendarAdded = true;
    }
  }

  let forwarded: "yes" | "maybe" | null = null;
  if (cities.size >= 2 || ips.size >= 3) forwarded = "yes";
  else if (uas.size >= 3) forwarded = "maybe";

  const entry = {
    sent_at: sentAt,
    delivered,
    opened,
    open_count: openCount,
    first_opened_at: firstOpenedAt,
    last_opened_at: lastOpenedAt,
    click_count: clickCount,
    calendar_added: calendarAdded,
    bounced,
    forwarded_status: forwarded,
    unique_cities: cities.size,
    unique_ips: ips.size,
    unique_devices: uas.size,
    updated_at: new Date().toISOString(),
  };

  const { data: regRow, error: regErr } = await supabase
    .from("registrations")
    .select("email_engagement")
    .eq("id", registrationId)
    .maybeSingle();

  if (regErr) {
    console.error("[resend-webhook] reg fetch", regErr);
    return;
  }

  const current =
    (regRow?.email_engagement as Record<string, unknown> | null | undefined) ||
    {};
  const next = { ...current, [slug]: entry };

  const { error: upErr } = await supabase
    .from("registrations")
    .update({ email_engagement: next, updated_at: new Date().toISOString() })
    .eq("id", registrationId);

  if (upErr) console.error("[resend-webhook] reg update", upErr);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return new Response("method_not_allowed", {
      status: 405,
      headers: cors,
    });
  }

  const secret = Deno.env.get("RESEND_WEBHOOK_SECRET");
  if (!secret) {
    console.error("[resend-webhook] RESEND_WEBHOOK_SECRET is not set");
    // 401 here is correct: no secret == can't verify.
    return new Response("webhook_secret_missing", { status: 401 });
  }

  const svixId = req.headers.get("svix-id") || "";
  const svixTimestamp = req.headers.get("svix-timestamp") || "";
  const svixSignature = req.headers.get("svix-signature") || "";
  if (!svixId || !svixTimestamp || !svixSignature) {
    return new Response("missing_svix_headers", { status: 401 });
  }

  const bodyText = await req.text();

  let event: ResendEvent;
  try {
    const wh = new Webhook(secret);
    event = wh.verify(bodyText, {
      "svix-id": svixId,
      "svix-timestamp": svixTimestamp,
      "svix-signature": svixSignature,
    }) as ResendEvent;
  } catch (err) {
    console.error("[resend-webhook] invalid signature", err);
    return new Response("invalid_signature", { status: 401 });
  }

  // Everything below returns 200 to Resend even on internal failures so the
  // webhook retry storm doesn't cause duplicate rows.
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    const tagsMap = tagsAsMap(event.data.tags);
    const registrationIdTag = tagsMap.registration_id;
    const templateSlug = tagsMap.template_slug || tagsMap.event_slug_template ||
      "";
    const recipientType = tagsMap.recipient_type || "main";

    // If the Resend tag block is missing OR unparseable, acknowledge with 200
    // but do nothing: we won't attribute events to registrations we can't find.
    if (!isUuid(registrationIdTag) || !templateSlug) {
      console.warn(
        "[resend-webhook] skipping untagged event",
        { type: event.type, tags: tagsMap },
      );
      return new Response(JSON.stringify({ ok: true, skipped: "untagged" }), {
        status: 200,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const evType = shortEvent(event.type);
    const emailId = String(event.data.email_id || "");
    const openBlock = event.data.open;
    const clickBlock = event.data.click;
    const occurredIso = (() => {
      const t = clickBlock?.timestamp || openBlock?.timestamp ||
        event.data.created_at || event.created_at;
      const d = t ? new Date(t) : new Date();
      return (isNaN(d.getTime()) ? new Date() : d).toISOString();
    })();

    const ip = clickBlock?.ipAddress || openBlock?.ipAddress || null;
    const ua = clickBlock?.userAgent || openBlock?.userAgent || null;
    const city = clickBlock?.city || openBlock?.city || null;
    const country = clickBlock?.country || openBlock?.country || null;
    const linkUrl = clickBlock?.link || null;
    const recipientEmail = firstEmail(event.data.to);

    const row = {
      registration_id: registrationIdTag,
      resend_email_id: emailId,
      email_template_slug: templateSlug,
      event_type: evType,
      recipient_type: recipientType,
      recipient_email: recipientEmail,
      occurred_at: occurredIso,
      link_url: linkUrl,
      ip_address: ip,
      user_agent: ua,
      city,
      country,
      raw_payload: event as unknown as Record<string, unknown>,
    };

    const { error: insErr } = await supabase
      .from("email_events")
      .upsert(row, {
        onConflict: "resend_email_id,event_type,occurred_at",
        ignoreDuplicates: true,
      });

    if (insErr) {
      // Duplicate rows are OK — unique index prevents double-counting.
      const msg = String(insErr.message || "");
      if (!/duplicate key|conflict/i.test(msg)) {
        console.error("[resend-webhook] insert failed", insErr);
      }
    }

    try {
      await recomputeEngagement(supabase, registrationIdTag, templateSlug);
    } catch (e) {
      console.error("[resend-webhook] recompute error", e);
    }

    return new Response(
      JSON.stringify({ ok: true, type: evType }),
      { status: 200, headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("[resend-webhook] internal", e);
    // Always ack 200 after signature passes, per PRD Section 8.1.
    return new Response(
      JSON.stringify({ ok: true, acked: true, error: String(e) }),
      { status: 200, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }
});
