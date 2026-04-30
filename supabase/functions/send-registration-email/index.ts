/**
 * send-registration-email
 *
 * - On approve: unique qr_token (+ plus_one_qr_token), PNGs of check-in URLs, Storage upload,
 *   Resend HTML with QR embedded as data:image/png (reliable in Outlook vs CID/external),
 *   optional +1 email from template slug approval-plus-one
 * - Deploy: supabase functions deploy send-registration-email --no-verify-jwt
 * - Secret (optional): PUBLIC_EVENTS_ORIGIN (default https://events.thehorecastore.com)
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import QRCode from "npm:qrcode@1.5.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Body = {
  registration_id: string;
  template_id: string;
  action_type: string;
  custom_message?: string;
  admin_email?: string;
};

function corsJson(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function applyIfBlocks(html: string, vars: Record<string, boolean>) {
  let out = html;
  for (const [key, truthy] of Object.entries(vars)) {
    const re = new RegExp(
      `\\{\\{#if ${key}\\}\\}([\\s\\S]*?)\\{\\{/if\\}\\}`,
      "g",
    );
    out = out.replace(re, (_m, inner: string) => (truthy ? inner : ""));
  }
  return out;
}

function interpolate(
  html: string,
  map: Record<string, string | null | undefined>,
) {
  let out = html;
  for (const [k, v] of Object.entries(map)) {
    const val = v == null ? "" : String(v);
    out = out.split(`{{${k}}}`).join(val);
  }
  return out;
}

/** Remove only simple {{variable}} tokens left unmatched (not {{#if}} / {{/if}}). */
function stripUnresolvedSimpleTags(html: string) {
  return html.replace(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g, "");
}

/** Google Calendar template dates: YYYYMMDDTHHmmssZ */
function formatGCalUtc(d: Date): string {
  return d.toISOString().replace(/\.\d{3}Z$/, "Z").replace(/[-:]/g, "");
}

/** Evening window from DB date-only (YYYY-MM-DD); ~6:30 PM US Central as 23:30 UTC + 4h. */
function eventWindowFromDateOnly(
  eventDateStr: string,
): { start: Date; end: Date } | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(eventDateStr).trim());
  if (!m) return null;
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  const start = new Date(Date.UTC(y, mo - 1, d, 23, 30, 0));
  const end = new Date(start.getTime() + 4 * 60 * 60 * 1000);
  return { start, end };
}

function buildGoogleCalendarUrl(opts: {
  title: string;
  details: string;
  location: string;
  start: Date;
  end: Date;
}): string {
  const dates = `${formatGCalUtc(opts.start)}/${formatGCalUtc(opts.end)}`;
  const u = new URL("https://calendar.google.com/calendar/render");
  u.searchParams.set("action", "TEMPLATE");
  u.searchParams.set("text", opts.title);
  u.searchParams.set("dates", dates);
  u.searchParams.set("details", opts.details);
  u.searchParams.set("location", opts.location);
  return u.toString();
}

function buildCalendarPageUrl(
  origin: string,
  opts: {
    title: string;
    details: string;
    location: string;
    start: Date;
    end: Date;
    uid: string;
  },
): string {
  const q = new URLSearchParams();
  q.set("t", opts.title);
  q.set("s", opts.start.toISOString());
  q.set("e", opts.end.toISOString());
  q.set("l", opts.location);
  q.set("d", opts.details);
  q.set("u", opts.uid);
  return `${origin}/calendar.html?${q.toString()}`;
}

/** Encode & for HTML href attributes (email-safe). */
function ampersandForHtmlAttr(url: string): string {
  return url.replace(/&/g, "&amp;");
}

function uint8ToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

/** HRC-XXXXXXXXXX-XXXXXXXX-XXXX style token */
function makeQrToken(): string {
  const id = crypto.randomUUID().replace(/-/g, "").toUpperCase();
  return `HRC-${id.slice(0, 10)}-${id.slice(10, 18)}-${id.slice(18, 22)}`;
}

async function qrPayloadToPngBytes(payload: string): Promise<Uint8Array> {
  const dataUrl = await new Promise<string>((resolve, reject) => {
    (QRCode as unknown as {
      toDataURL: (
        text: string,
        opts: object,
        cb: (err: Error | null | undefined, url: string) => void,
      ) => void;
    }).toDataURL(
      payload,
      {
        type: "image/png",
        width: 512,
        margin: 2,
        errorCorrectionLevel: "M",
      },
      (err, url) => {
        if (err) reject(err);
        else resolve(url);
      },
    );
  });
  const b64 = dataUrl.replace(/^data:image\/png;base64,/, "");
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function sendResend(params: {
  apiKey: string;
  from: string;
  fromName: string;
  to: string[];
  subject: string;
  html: string;
  attachments?: {
    filename: string;
    content: string;
    content_id?: string;
    content_type?: string;
  }[];
}) {
  const { apiKey, from, fromName, to, subject, html, attachments } = params;
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: `${fromName} <${from}>`,
      to,
      subject,
      html,
      attachments: attachments ?? [],
    }),
  });
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`resend ${res.status}: ${txt}`);
  }
  return res.json();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const resendKey = Deno.env.get("RESEND_API_KEY");
    const fromEmail = Deno.env.get("FROM_EMAIL") || "events@thehorecastore.com";
    const fromName = Deno.env.get("FROM_NAME") || "The Horeca Meetup";
    const eventsOrigin =
      Deno.env.get("PUBLIC_EVENTS_ORIGIN") ||
      "https://events.thehorecastore.com";

    const supabase = createClient(supabaseUrl, serviceKey);

    const body = (await req.json()) as Body;
    const { registration_id, template_id, action_type, custom_message = "" } =
      body;

    if (!registration_id || !template_id || !action_type) {
      return corsJson({ error: "missing_fields" }, 400);
    }

    const checkinLink = (token: string) =>
      `${eventsOrigin}/checkin.html?t=${encodeURIComponent(token)}`;

    const { data: reg, error: regErr } = await supabase
      .from("registrations")
      .select("*")
      .eq("id", registration_id)
      .single();

    if (regErr || !reg) {
      console.error("registration fetch", regErr);
      return corsJson(
        { error: "registration_not_found", detail: regErr?.message },
        400,
      );
    }

    let ev: Record<string, unknown> | null = null;
    const eventId = reg.event_id as string | undefined;
    if (eventId) {
      const { data: evRow, error: evErr } = await supabase
        .from("events")
        .select("city, volume_roman, event_date, slug")
        .eq("id", eventId)
        .maybeSingle();
      if (evErr) console.error("event fetch", evErr);
      else if (evRow) ev = evRow as Record<string, unknown>;
    }

    const { data: template, error: tErr } = await supabase
      .from("email_templates")
      .select("id, slug, name, subject, body_html")
      .eq("id", template_id)
      .single();

    if (tErr || !template) {
      console.error("template fetch", tErr);
      return corsJson(
        { error: "template_not_found", detail: tErr?.message },
        400,
      );
    }

    const rawHtml = template.body_html;
    const rawSubject = template.subject;
    if (!rawHtml || !String(rawHtml).trim()) {
      return corsJson(
        { error: "empty_body_html", template_id, slug: template.slug },
        400,
      );
    }

    let qrUrl = reg.qr_code_url as string | null;
    let plusOneUrl = reg.plus_one_qr_code_url as string | null;
    let qrToken = reg.qr_token as string | null;
    let plusOneToken = reg.plus_one_qr_token as string | null;
    let pngMainBytes: Uint8Array | null = null;
    let pngPlusBytes: Uint8Array | null = null;

    if (action_type === "approve") {
      qrToken = makeQrToken();
      const hasPlus = Boolean(reg.has_plus_one);
      plusOneToken = hasPlus ? makeQrToken() : null;

      const urlMain = checkinLink(qrToken);
      let urlPlus: string | null = null;
      try {
        pngMainBytes = await qrPayloadToPngBytes(urlMain);
      } catch (e) {
        console.error("QR main", e);
        return corsJson(
          { error: "qr_generation_failed", detail: String(e) },
          500,
        );
      }

      if (plusOneToken) {
        urlPlus = checkinLink(plusOneToken);
        try {
          pngPlusBytes = await qrPayloadToPngBytes(urlPlus);
        } catch (e) {
          console.error("QR plus", e);
          return corsJson(
            { error: "qr_generation_failed_plus_one", detail: String(e) },
            500,
          );
        }
      }

      const mainPath = `${registration_id}-main.png`;
      const { error: upMain } = await supabase.storage
        .from("qr-codes")
        .upload(mainPath, pngMainBytes, {
          contentType: "image/png",
          upsert: true,
        });
      if (upMain) {
        console.error("storage main", upMain);
        return corsJson(
          {
            error: "qr_upload_failed",
            detail: upMain.message,
            hint: "Bucket qr-codes, service role",
          },
          500,
        );
      }
      const { data: pubM } = supabase.storage.from("qr-codes").getPublicUrl(
        mainPath,
      );
      qrUrl = pubM.publicUrl;

      const patch: Record<string, unknown> = {
        qr_token: qrToken,
        qr_code_url: qrUrl,
        updated_at: new Date().toISOString(),
      };

      if (plusOneToken && pngPlusBytes) {
        const plusPath = `${registration_id}-plus1.png`;
        const { error: upP } = await supabase.storage
          .from("qr-codes")
          .upload(plusPath, pngPlusBytes, {
            contentType: "image/png",
            upsert: true,
          });
        if (upP) {
          console.error("storage plus", upP);
          return corsJson(
            { error: "qr_upload_failed_plus_one", detail: upP.message },
            500,
          );
        }
        const { data: pubP } = supabase.storage.from("qr-codes").getPublicUrl(
          plusPath,
        );
        plusOneUrl = pubP.publicUrl;
        patch.plus_one_qr_token = plusOneToken;
        patch.plus_one_qr_code_url = plusOneUrl;
      } else {
        patch.plus_one_qr_token = null;
        patch.plus_one_qr_code_url = null;
      }

      const { error: qrUpdErr } = await supabase
        .from("registrations")
        .update(patch)
        .eq("id", registration_id);

      if (qrUpdErr) {
        console.error("registration qr patch", qrUpdErr);
        return corsJson(
          { error: "qr_url_persist_failed", detail: qrUpdErr.message },
          500,
        );
      }
    }

    const eventDate = ev?.event_date
      ? new Date(ev.event_date as string)
      : null;
    const eventDateLong = eventDate
      ? eventDate.toLocaleDateString("en-US", {
        weekday: "long",
        month: "long",
        day: "numeric",
        year: "numeric",
      })
      : "";
    const eventDateShort = eventDate
      ? eventDate.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        year: "numeric",
      })
      : "";

    const hasPlus = Boolean(reg.has_plus_one);
    const plusOneFull = `${reg.plus_one_first_name ?? ""} ${reg.plus_one_last_name ?? ""}`
      .trim();
    const resId = String(reg.id).slice(0, 8).toUpperCase();
    const eventCity = (ev?.city as string) ?? "Houston";
    const eventVolume = String((ev?.volume_roman as string) ?? "");
    const meetupTitle = `The Horeca Meetup ${eventCity} Vol. ${eventVolume}`;
    const venueLine =
      "Marriott Energy Corridor, 16011 Katy Freeway, Houston, TX";
    const win = ev?.event_date
      ? eventWindowFromDateOnly(String(ev.event_date))
      : null;
    let calendarGoogleUrl = `${eventsOrigin}/calendar.html`;
    let calendarIcsUrl = `${eventsOrigin}/calendar.html`;
    if (win) {
      const descBody =
        `Doors 6:00 PM · Program 6:30 PM · Reservation #${resId}. Check-in: ${eventsOrigin}/checkin.html`;
      calendarGoogleUrl = ampersandForHtmlAttr(
        buildGoogleCalendarUrl({
          title: meetupTitle,
          details: descBody,
          location: venueLine,
          start: win.start,
          end: win.end,
        }),
      );
      calendarIcsUrl = ampersandForHtmlAttr(
        buildCalendarPageUrl(eventsOrigin, {
          title: meetupTitle,
          details: descBody,
          location: venueLine,
          start: win.start,
          end: win.end,
          uid: resId,
        }),
      );
    }

    const vars: Record<string, string> = {
      first_name: reg.first_name ?? "",
      last_name: reg.last_name ?? "",
      full_name: `${reg.first_name ?? ""} ${reg.last_name ?? ""}`.trim(),
      business_name: reg.business_name ?? "",
      event_city: eventCity,
      event_volume: eventVolume,
      event_date_long: eventDateLong,
      event_date_short: eventDateShort,
      event_doors: "6:00 PM",
      event_start: "6:30 PM",
      venue_name: "Marriott Energy Corridor",
      venue_address: "16011 Katy Freeway, Houston, TX",
      qr_code_url: qrUrl || "",
      plus_one_name: hasPlus ? plusOneFull : "",
      plus_one_first_name: hasPlus
        ? (reg.plus_one_first_name ?? "")
        : (reg.first_name ?? ""),
      plus_one_full_name: hasPlus ? plusOneFull : (
        `${reg.first_name ?? ""} ${reg.last_name ?? ""}`.trim()
      ),
      host_first_name: reg.first_name ?? "",
      host_last_name: reg.last_name ?? "",
      host_full_name:
        `${reg.first_name ?? ""} ${reg.last_name ?? ""}`.trim(),
      host_business: reg.business_name ?? "",
      plus_one_email: reg.plus_one_email ?? "",
      reservation_id: resId,
      calendar_google_url: calendarGoogleUrl,
      calendar_ics_url: calendarIcsUrl,
      custom_message: custom_message || "",
    };

    let html = applyIfBlocks(String(rawHtml), { has_plus_one: hasPlus });
    html = interpolate(html, vars);

    let subject = interpolate(String(rawSubject), vars);

    if (!resendKey) {
      console.warn("RESEND_API_KEY missing — skip send");
      return corsJson({
        ok: true,
        skipped_email: true,
        qr_code_url: qrUrl,
        plus_one_qr_code_url: plusOneUrl,
        qr_token: qrToken,
        plus_one_qr_token: plusOneToken,
        message: "QR saved but RESEND_API_KEY not set",
      });
    }

    if (action_type === "approve" && pngMainBytes) {
      // Inline PNG as data-URL so Outlook shows the QR without CID / external fetch.
      const mainDataUrl =
        `data:image/png;base64,${uint8ToBase64(pngMainBytes)}`;
      const emailVars: Record<string, string> = {
        ...vars,
        qr_code_url: mainDataUrl,
        // If approval template row mistakenly uses +1 img variable, still show the guest QR.
        plus_one_qr_code_url: mainDataUrl,
      };
      let emailHtml = applyIfBlocks(String(rawHtml), { has_plus_one: hasPlus });
      emailHtml = interpolate(emailHtml, emailVars);
      emailHtml = stripUnresolvedSimpleTags(emailHtml);
      try {
        await sendResend({
          apiKey: resendKey,
          from: fromEmail,
          fromName,
          to: [reg.email as string],
          subject,
          html: emailHtml,
        });
      } catch (e) {
        console.error(e);
        return corsJson(
          { error: "resend_failed", detail: String(e) },
          502,
        );
      }

      if (
        hasPlus && pngPlusBytes && reg.plus_one_email &&
        String(reg.plus_one_email).trim()
      ) {
        const { data: plusTpl } = await supabase
          .from("email_templates")
          .select("id, slug, subject, body_html")
          .eq("slug", "approval-plus-one")
          .eq("is_active", true)
          .maybeSingle();

        if (plusTpl?.body_html && String(plusTpl.body_html).trim()) {
          const poEmail = String(reg.plus_one_email).trim().toLowerCase();
          const plusDataUrl =
            `data:image/png;base64,${uint8ToBase64(pngPlusBytes)}`;
          const plusVars: Record<string, string> = {
            ...vars,
            plus_one_first_name: reg.plus_one_first_name ?? "",
            plus_one_full_name: plusOneFull,
            host_first_name: reg.first_name ?? "",
            host_last_name: reg.last_name ?? "",
            host_full_name: vars.full_name,
            host_business: reg.business_name ?? "",
            plus_one_qr_code_url: plusDataUrl,
            qr_code_url: plusDataUrl,
          };
          let pHtml = applyIfBlocks(String(plusTpl.body_html), {
            has_plus_one: true,
          });
          pHtml = interpolate(pHtml, plusVars);
          pHtml = stripUnresolvedSimpleTags(pHtml);
          const pSub = interpolate(String(plusTpl.subject ?? ""), plusVars);
          try {
            await sendResend({
              apiKey: resendKey,
              from: fromEmail,
              fromName,
              to: [poEmail],
              subject: pSub,
              html: pHtml,
            });
          } catch (e) {
            console.error("plus-one resend", e);
            return corsJson(
              {
                error: "resend_failed_plus_one",
                detail: String(e),
                main_sent: true,
              },
              502,
            );
          }
        }
      }

      return corsJson({
        ok: true,
        qr_code_url: qrUrl,
        plus_one_qr_code_url: plusOneUrl,
        qr_token: qrToken,
        plus_one_qr_token: plusOneToken,
      });
    }

    const to = reg.email as string;
    try {
      const sent = await sendResend({
        apiKey: resendKey,
        from: fromEmail,
        fromName,
        to: [to],
        subject,
        html,
      });
      return corsJson({ ok: true, id: (sent as { id?: string }).id });
    } catch (e) {
      console.error(e);
      return corsJson({ error: "resend_failed", detail: String(e) }, 502);
    }
  } catch (e) {
    console.error(e);
    return corsJson({ error: "internal", detail: String(e) }, 500);
  }
});
