-- ═══════════════════════════════════════════════════════════════════════
-- Vol III early-interest acknowledgement email template
--
-- Sent automatically by the send-vol3-interest edge function when someone
-- reserves their name through /vol-3.html. Completely isolated from the
-- Vol II template set and from the main send-registration-email flow.
--
-- Variables used:
--   {{first_name}}
--   {{event_date_long}}    (e.g. "Tuesday, September 8, 2026")
--   {{venue_name}}
--   {{venue_address}}
--   {{has_plus_one}}       (boolean used by the {{#if}} block)
--   {{plus_one_name}}
-- ═══════════════════════════════════════════════════════════════════════

INSERT INTO public.email_templates (slug, name, subject, body_html, body_text, category, is_active, audience)
VALUES (
  'vol3-early-interest',
  'Vol III Early Interest Acknowledgement',
  'We have saved your name for Vol. III, September 8 2026',
  $HTML$<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>We have saved your name for Vol. III</title></head>
<body style="margin:0;padding:0;background-color:#f5f1e8;font-family:Georgia,'Times New Roman',serif;">
<div style="display:none;max-height:0;overflow:hidden;">Thank you for your early interest. Formal invitations go out in July. We will be in touch.</div>

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f5f1e8;padding:40px 20px;"><tr><td align="center">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#ffffff;border:1px solid #e8dcc4;">

<!-- ━━━ CANONICAL HEADER ━━━ -->
<tr><td style="height:4px;background:linear-gradient(90deg,#8b6f3a,#c9a55c,#e0c186);font-size:0;line-height:0;">&nbsp;</td></tr>
<tr><td style="background-color:#0a0a0a;padding:32px 40px;text-align:center;">
<div style="font-family:'Fraunces',Georgia,serif;font-size:24px;font-weight:500;color:#ffffff;letter-spacing:-0.01em;">The Horeca <em style="font-style:italic;color:#c9a55c;">Meetup</em></div>
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#c9a55c;text-transform:uppercase;margin-top:8px;">Houston · Volume III</div>
</td></tr>

<!-- ━━━ BODY ━━━ -->
<tr><td style="padding:48px 40px 24px 40px;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:16px;">Early Interest Received · Vol. III</div>
<h1 style="margin:0 0 24px 0;font-family:'Fraunces',Georgia,serif;font-size:36px;font-weight:400;line-height:1.1;color:#0a0a0a;letter-spacing:-0.02em;">Hi <em style="font-style:italic;color:#8b6f3a;">{{first_name}}.</em></h1>
<p style="margin:0 0 18px 0;font-size:16px;line-height:1.7;color:#3a3a3a;">Thank you for reserving early for <strong>The Horeca Meetup Houston Vol. III</strong>. We have noted your interest and added you to the Vol. III shortlist.</p>
<p style="margin:0 0 18px 0;font-size:16px;line-height:1.7;color:#3a3a3a;">A quick word on what happens next. Vol. III is an invitation-only evening and we keep the room small on purpose. Formal invitations go out roughly 60 days before the event, which lands in early July 2026. When that window opens you will hear from us personally. Once your seat is confirmed, you will receive a reservation email with your details and QR code.</p>
{{#if has_plus_one}}<p style="margin:0 0 18px 0;font-size:16px;line-height:1.7;color:#3a3a3a;">We have also noted <strong>{{plus_one_name}}</strong> as your guest. Their seat is held alongside yours.</p>{{/if}}
<p style="margin:0 0 18px 0;font-size:16px;line-height:1.7;color:#3a3a3a;">In the meantime, please save the date.</p>
</td></tr>

<!-- ━━━ DATE BLOCK ━━━ -->
<tr><td style="padding:0 40px 32px 40px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#fdfaf3;border:1px solid #e8dcc4;">
<tr><td style="padding:28px 24px;text-align:center;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:12px;">Save the Date</div>
<div style="font-family:'Fraunces',Georgia,serif;font-size:22px;font-weight:500;color:#0a0a0a;line-height:1.3;margin-bottom:8px;">Tuesday, September 8 2026</div>
<div style="font-family:'Fraunces',Georgia,serif;font-size:16px;color:#3a3a3a;line-height:1.5;margin-bottom:4px;"><strong>Marriott Energy Corridor</strong>, Houston</div>
<div style="font-family:Georgia,serif;font-size:14px;color:#6b6b6b;line-height:1.6;">Doors 6:00 PM. Dinner 6:30 PM.</div>
<div style="font-family:Georgia,serif;font-size:14px;color:#6b6b6b;line-height:1.6;">Buffet dinner. Welcome reception.</div>
<div style="font-family:Georgia,serif;font-size:14px;font-style:italic;color:#8b6f3a;line-height:1.6;margin-top:8px;">Complimentary, by invitation.</div>
</td></tr>
</table>
</td></tr>

<!-- ━━━ CTA ━━━ -->
<tr><td style="padding:0 40px 32px 40px;text-align:center;">
<a href="https://calendar.google.com/calendar/render?action=TEMPLATE&text=The+Horeca+Meetup+%C2%B7+Houston+Vol.+III&dates=20260908T230000Z/20260909T030000Z&details=A+private+dinner+for+restaurant+and+hotel+owners.+By+invitation+only.&location=Marriott+Energy+Corridor%2C+Houston%2C+TX" style="display:inline-block;background-color:#0a0a0a;color:#c9a55c;padding:14px 32px;text-decoration:none;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.16em;text-transform:uppercase;border:1px solid #c9a55c;">Add Vol. III to Your Calendar</a>
</td></tr>

<!-- ━━━ CLOSING ━━━ -->
<tr><td style="padding:0 40px 32px 40px;">
<p style="margin:0;font-size:15px;line-height:1.7;color:#3a3a3a;">If anything changes on your end, a new business, a change of role, a guest you want to bring, just reply to this email and we will note it down.</p>
</td></tr>

<!-- ━━━ SIGN OFF ━━━ -->
<tr><td style="padding:0 40px 40px 40px;border-top:1px solid #e8dcc4;padding-top:32px;">
<p style="margin:0;font-family:'Fraunces',Georgia,serif;font-size:16px;font-style:italic;color:#0a0a0a;">Looking forward to seeing you in September.</p>
<p style="margin:16px 0 0 0;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;">Noman Peera<br><span style="color:#6b6b6b;">CEO · Horeca Store</span></p>
</td></tr>

<!-- ━━━ CANONICAL FOOTER ━━━ -->
<tr><td style="background-color:#0a0a0a;padding:36px 40px;text-align:center;">
<div style="font-family:'Fraunces',Georgia,serif;font-size:20px;font-weight:500;color:#ffffff;margin-bottom:8px;letter-spacing:-0.01em;">Horeca <em style="font-style:italic;color:#c9a55c;">Meetup</em></div>
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.2em;color:#8b6f3a;text-transform:uppercase;margin-bottom:16px;">A Private Series For Restaurant And Hotel Owners</div>
<div style="font-family:Georgia,serif;font-size:12px;color:#6b6b6b;line-height:1.6;">Hosted by <a href="https://thehorecastore.com" style="color:#c9a55c;text-decoration:none;">Horeca Store</a>. Trusted by 15,000+ hotels and restaurants across 11 countries.</div>
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.18em;color:#6b6b6b;text-transform:uppercase;margin-top:16px;">events@thehorecastore.com · +1 866 446 7322</div>
</td></tr>

</table>
</td></tr></table>
</body>
</html>$HTML$,
  $TEXT$Hi {{first_name}},

Thank you for reserving early for The Horeca Meetup Houston Vol. III. We have noted your interest and added you to the Vol. III shortlist.

A quick word on what happens next. Vol. III is an invitation-only evening and we keep the room small on purpose. Formal invitations go out roughly 60 days before the event, which lands in early July 2026. When that window opens you will hear from us personally. Once your seat is confirmed, you will receive a reservation email with your details and QR code.

In the meantime, please save the date.

  Tuesday, September 8 2026
  Marriott Energy Corridor, Houston
  Doors 6:00 PM. Dinner 6:30 PM.
  Buffet dinner. Welcome reception.
  Complimentary, by invitation.

Add to your calendar:
https://calendar.google.com/calendar/render?action=TEMPLATE&text=The+Horeca+Meetup+%C2%B7+Houston+Vol.+III&dates=20260908T230000Z/20260909T030000Z&location=Marriott+Energy+Corridor%2C+Houston%2C+TX

If anything changes on your end, a new business, a change of role, a guest you want to bring, just reply to this email and we will note it down.

Looking forward to seeing you in September.

Noman Peera
CEO, Horeca Store
events@thehorecastore.com
+1 866 446 7322$TEXT$,
  'vol3',
  true,
  'primary'
)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  subject = EXCLUDED.subject,
  body_html = EXCLUDED.body_html,
  body_text = EXCLUDED.body_text,
  category = EXCLUDED.category,
  is_active = EXCLUDED.is_active,
  audience = EXCLUDED.audience,
  updated_at = now();
