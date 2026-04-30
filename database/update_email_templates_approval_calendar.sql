-- Sync approval templates from repo (emails/*.html)
BEGIN;
UPDATE email_templates
SET body_html = $horeca_tpl$<!DOCTYPE html>
<!-- ═══════════════════════════════════════════════════════════════════════
     APPROVAL EMAIL · MAIN ATTENDEE
     Sent to the person who filled out the form.
     If they brought a +1, the +1 receives a SEPARATE email (approval-plus-one.html).
     Variables: {{first_name}}, {{full_name}}, {{business_name}}, {{event_city}},
                {{event_volume}}, {{event_date_long}}, {{event_doors}}, {{event_start}},
                {{venue_name}}, {{venue_address}}, {{qr_code_url}}, {{has_plus_one}},
                {{plus_one_name}}, {{plus_one_email}}, {{reservation_id}}
     ═══════════════════════════════════════════════════════════════════════ -->
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>You are confirmed for The Horeca Meetup</title></head>
<body style="margin:0;padding:0;background-color:#f5f1e8;font-family:Georgia,'Times New Roman',serif;">
<div style="display:none;max-height:0;overflow:hidden;">Your seat is confirmed for {{event_city}} Vol. {{event_volume}} on {{event_date_short}}. Your QR code is below.</div>

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f5f1e8;padding:40px 20px;"><tr><td align="center">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#ffffff;border:1px solid #e8dcc4;">

<!-- ━━━ CANONICAL HEADER ━━━ -->
<tr><td style="height:4px;background:linear-gradient(90deg,#8b6f3a,#c9a55c,#e0c186);font-size:0;line-height:0;">&nbsp;</td></tr>
<tr><td style="background-color:#0a0a0a;padding:32px 40px;text-align:center;">
<div style="font-family:'Fraunces',Georgia,serif;font-size:24px;font-weight:500;color:#ffffff;letter-spacing:-0.01em;">The Horeca <em style="font-style:italic;color:#c9a55c;">Meetup</em></div>
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#c9a55c;text-transform:uppercase;margin-top:8px;">{{event_city}} · Volume {{event_volume}}</div>
</td></tr>

<!-- ━━━ BODY ━━━ -->
<tr><td style="padding:48px 40px 24px 40px;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:16px;">Confirmation · Reservation #{{reservation_id}}</div>
<h1 style="margin:0 0 24px 0;font-family:'Fraunces',Georgia,serif;font-size:36px;font-weight:400;line-height:1.1;color:#0a0a0a;letter-spacing:-0.02em;">You are confirmed,<br><em style="font-style:italic;color:#8b6f3a;">{{first_name}}.</em></h1>
<p style="margin:0 0 16px 0;font-size:16px;line-height:1.6;color:#3a3a3a;">Your seat at <strong>The Horeca Meetup {{event_city}} Vol. {{event_volume}}</strong> is reserved. We are looking forward to having you in the room.</p>
{{#if has_plus_one}}<p style="margin:0 0 16px 0;font-size:16px;line-height:1.6;color:#3a3a3a;">We have also sent <strong>{{plus_one_name}}</strong> their own confirmation email at <strong>{{plus_one_email}}</strong> with their personal QR code. Please make sure they check their inbox.</p>{{/if}}
<p style="margin:0;font-size:16px;line-height:1.6;color:#3a3a3a;">Bring your appetite, your questions, and the operators who built what you built. The room is yours.</p>
</td></tr>

<!-- QR CODE BLOCK -->
<tr><td style="padding:24px 40px;">
<div style="border:1px solid #e8dcc4;background-color:#fdfaf3;padding:32px 24px;text-align:center;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:8px;">Your Entry Pass</div>
<div style="font-family:'Fraunces',Georgia,serif;font-size:18px;font-style:italic;color:#0a0a0a;margin-bottom:20px;">Show this at the door</div>
<img src="{{qr_code_url}}" alt="Your QR Code" width="240" height="240" style="display:block;margin:0 auto;border:0;width:240px;height:240px;background-color:#ffffff;padding:12px;">
<div style="font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;margin-top:16px;">{{full_name}} · {{business_name}}</div>
</div>
</td></tr>

<!-- EVENT DETAILS -->
<tr><td style="padding:24px 40px;">
<div style="border-top:1px solid #e8dcc4;padding-top:32px;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:20px;">The Evening</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0">
<tr><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;width:140px;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;vertical-align:top;">Date</td><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#0a0a0a;">{{event_date_long}}</td></tr>
<tr><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;vertical-align:top;">Doors</td><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#0a0a0a;">{{event_doors}}</td></tr>
<tr><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;vertical-align:top;">Program Begins</td><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#0a0a0a;">{{event_start}}</td></tr>
<tr><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;vertical-align:top;">Buffet Dinner</td><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#0a0a0a;">8:30 PM</td></tr>
<tr><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;vertical-align:top;">Venue</td><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#0a0a0a;">{{venue_name}}<br><span style="font-size:13px;color:#6b6b6b;">{{venue_address}}</span></td></tr>
<tr><td style="padding:8px 0;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;vertical-align:top;">Dress Code</td><td style="padding:8px 0;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#0a0a0a;">Business / Smart Casual</td></tr>
</table>
</div>
</td></tr>

<!-- WHAT TO EXPECT -->
<tr><td style="padding:24px 40px 40px 40px;">
<div style="background-color:#fdfaf3;border:1px solid #e8dcc4;padding:28px;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:14px;">What to Expect</div>
<ul style="margin:0;padding:0 0 0 20px;font-family:'Fraunces',Georgia,serif;font-size:15px;line-height:1.8;color:#3a3a3a;">
<li>Welcome reception with restaurant and hotel owners from across Houston</li>
<li>A working session on scaling profitably in 2026</li>
<li>An honest operator panel on growth, franchising, and the real numbers</li>
<li>Buffet dinner with curated room flow</li>
<li>The kind of conversations that turn rooms into networks</li>
</ul>
</div>
</td></tr>

<!-- ADD TO CALENDAR -->
<tr><td style="padding:0 40px 32px 40px;text-align:center;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:16px;">Don't Miss It</div>
<table role="presentation" cellpadding="0" cellspacing="0" align="center" style="margin:0 auto;"><tr>
<td style="padding:6px;vertical-align:middle;">
<a href="{{calendar_google_url}}" style="display:inline-block;background-color:#0a0a0a;color:#c9a55c;padding:14px 22px;text-decoration:none;font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.12em;text-transform:uppercase;border:1px solid #c9a55c;">Add to Google Calendar</a>
</td>
<td style="padding:6px;vertical-align:middle;">
<a href="{{calendar_ics_url}}" style="display:inline-block;background-color:#fdfaf3;color:#0a0a0a;padding:14px 22px;text-decoration:none;font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.12em;text-transform:uppercase;border:1px solid #c9a55c;">Apple / Outlook (.ics)</a>
</td>
</tr></table>
</td></tr>

<!-- CLOSING -->
<tr><td style="padding:0 40px 40px 40px;border-top:1px solid #e8dcc4;padding-top:32px;">
<p style="margin:0 0 12px 0;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#3a3a3a;line-height:1.6;">Questions? Just reply to this email or write to <a href="mailto:events@thehorecastore.com" style="color:#8b6f3a;">events@thehorecastore.com</a>.</p>
<p style="margin:0;font-family:'Fraunces',Georgia,serif;font-size:16px;font-style:italic;color:#0a0a0a;">We will see you at the table.</p>
<p style="margin:24px 0 0 0;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;">Noman Peera<br><span style="color:#6b6b6b;">CEO · Horeca Store</span></p>
</td></tr>

<!-- ━━━ CANONICAL FOOTER ━━━ -->
<tr><td style="background-color:#0a0a0a;padding:36px 40px;text-align:center;">
<div style="font-family:'Fraunces',Georgia,serif;font-size:20px;font-weight:500;color:#ffffff;margin-bottom:8px;letter-spacing:-0.01em;">Horeca <em style="font-style:italic;color:#c9a55c;">Store</em></div>
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.2em;color:#a8a8a8;text-transform:uppercase;margin-bottom:24px;">Global Hospitality Supply · 11 Countries · 3 Continents</div>
<div style="font-family:'Fraunces',Georgia,serif;font-size:13px;font-style:italic;color:#a8a8a8;line-height:1.7;max-width:380px;margin:0 auto;">Trusted by 15,000+ hotels and restaurants across the Middle East, Asia, and the United States</div>
<div style="margin-top:28px;padding-top:24px;border-top:1px solid #2a2a2a;">
<a href="https://thehorecastore.com" style="font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.18em;color:#c9a55c;text-decoration:none;text-transform:uppercase;">thehorecastore.com</a>
<span style="color:#3a3a3a;margin:0 12px;">·</span>
<a href="mailto:events@thehorecastore.com" style="font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.18em;color:#c9a55c;text-decoration:none;text-transform:uppercase;">events@thehorecastore.com</a>
</div>
</td></tr>

</table>
<p style="margin:24px 0 0 0;font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.1em;color:#8b6f3a;text-align:center;text-transform:uppercase;">You are receiving this because you applied for {{event_city}} Vol. {{event_volume}}</p>
</td></tr></table>
</body></html>
$horeca_tpl$,
    updated_at = NOW()
WHERE slug = 'approval';

UPDATE email_templates
SET body_html = $horeca_tpl$<!DOCTYPE html>
<!-- ═══════════════════════════════════════════════════════════════════════
     APPROVAL EMAIL · PLUS-ONE GUEST
     ═══════════════════════════════════════════════════════════════════════
     Sent ONLY to the +1 guest (the second person in the registration).
     Framing: "{{host_full_name}} registered you for this event."
     Includes their OWN unique QR code (separate from the host's QR).
     
     Variables:
       {{plus_one_first_name}}, {{plus_one_full_name}}
       {{host_first_name}}, {{host_full_name}}, {{host_business}}
       {{event_city}}, {{event_volume}}, {{event_date_long}}, {{event_doors}},
       {{event_start}}, {{venue_name}}, {{venue_address}},
       {{plus_one_qr_code_url}}, {{reservation_id}}
     ═══════════════════════════════════════════════════════════════════════ -->
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>{{host_first_name}} registered you for The Horeca Meetup</title></head>
<body style="margin:0;padding:0;background-color:#f5f1e8;font-family:Georgia,'Times New Roman',serif;">
<div style="display:none;max-height:0;overflow:hidden;">{{host_first_name}} {{host_last_name}} reserved a seat for you at The Horeca Meetup {{event_city}} Vol. {{event_volume}}. Your QR code is below.</div>

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f5f1e8;padding:40px 20px;"><tr><td align="center">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#ffffff;border:1px solid #e8dcc4;">

<!-- ━━━ CANONICAL HEADER ━━━ -->
<tr><td style="height:4px;background:linear-gradient(90deg,#8b6f3a,#c9a55c,#e0c186);font-size:0;line-height:0;">&nbsp;</td></tr>
<tr><td style="background-color:#0a0a0a;padding:32px 40px;text-align:center;">
<div style="font-family:'Fraunces',Georgia,serif;font-size:24px;font-weight:500;color:#ffffff;letter-spacing:-0.01em;">The Horeca <em style="font-style:italic;color:#c9a55c;">Meetup</em></div>
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#c9a55c;text-transform:uppercase;margin-top:8px;">{{event_city}} · Volume {{event_volume}}</div>
</td></tr>

<!-- ━━━ INVITATION FRAMING (this is the key difference) ━━━ -->
<tr><td style="padding:40px 40px 0 40px;">
<div style="background-color:#fdfaf3;border:1px solid #e8dcc4;padding:24px;text-align:center;border-left:3px solid #c9a55c;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:8px;">You Have Been Invited</div>
<div style="font-family:'Fraunces',Georgia,serif;font-size:18px;color:#0a0a0a;font-style:italic;line-height:1.5;">
{{host_first_name}} {{host_last_name}} from <strong style="font-style:normal;">{{host_business}}</strong><br>
has reserved a seat for you.
</div>
</div>
</td></tr>

<!-- ━━━ BODY ━━━ -->
<tr><td style="padding:32px 40px 24px 40px;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:16px;">Confirmation · Reservation #{{reservation_id}}</div>
<h1 style="margin:0 0 24px 0;font-family:'Fraunces',Georgia,serif;font-size:36px;font-weight:400;line-height:1.1;color:#0a0a0a;letter-spacing:-0.02em;">Hello, <em style="font-style:italic;color:#8b6f3a;">{{plus_one_first_name}}.</em></h1>
<p style="margin:0 0 16px 0;font-size:16px;line-height:1.6;color:#3a3a3a;">
Your seat at <strong>The Horeca Meetup {{event_city}} Vol. {{event_volume}}</strong> has been reserved by {{host_first_name}}. We are looking forward to having you in the room.
</p>
<p style="margin:0 0 16px 0;font-size:16px;line-height:1.6;color:#3a3a3a;">
The Horeca Meetup is a private quarterly dinner series for restaurant and hotel owners. The room is curated, the conversations are honest, and the network compounds across editions.
</p>
<p style="margin:0;font-size:16px;line-height:1.6;color:#3a3a3a;">
Below is <strong>your personal QR code</strong>. Please bring it with you and show it at the door for entry.
</p>
</td></tr>

<!-- QR CODE BLOCK -->
<tr><td style="padding:24px 40px;">
<div style="border:1px solid #e8dcc4;background-color:#fdfaf3;padding:32px 24px;text-align:center;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:8px;">Your Entry Pass</div>
<div style="font-family:'Fraunces',Georgia,serif;font-size:18px;font-style:italic;color:#0a0a0a;margin-bottom:20px;">Show this at the door</div>
<img src="{{plus_one_qr_code_url}}" alt="Your QR Code" width="240" height="240" style="display:block;margin:0 auto;border:0;width:240px;height:240px;background-color:#ffffff;padding:12px;">
<div style="font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;margin-top:16px;">{{plus_one_full_name}} · Guest of {{host_first_name}} {{host_last_name}}</div>
</div>
</td></tr>

<!-- EVENT DETAILS -->
<tr><td style="padding:24px 40px;">
<div style="border-top:1px solid #e8dcc4;padding-top:32px;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:20px;">The Evening</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0">
<tr><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;width:140px;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;vertical-align:top;">Date</td><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#0a0a0a;">{{event_date_long}}</td></tr>
<tr><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;vertical-align:top;">Doors</td><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#0a0a0a;">{{event_doors}}</td></tr>
<tr><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;vertical-align:top;">Program Begins</td><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#0a0a0a;">{{event_start}}</td></tr>
<tr><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;vertical-align:top;">Buffet Dinner</td><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#0a0a0a;">8:30 PM</td></tr>
<tr><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;vertical-align:top;">Venue</td><td style="padding:8px 0;border-bottom:1px solid #f0e8d4;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#0a0a0a;">{{venue_name}}<br><span style="font-size:13px;color:#6b6b6b;">{{venue_address}}</span></td></tr>
<tr><td style="padding:8px 0;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;vertical-align:top;">Dress Code</td><td style="padding:8px 0;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#0a0a0a;">Business / Smart Casual</td></tr>
</table>
</div>
</td></tr>

<!-- WHAT TO EXPECT -->
<tr><td style="padding:24px 40px 40px 40px;">
<div style="background-color:#fdfaf3;border:1px solid #e8dcc4;padding:28px;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:14px;">What to Expect</div>
<ul style="margin:0;padding:0 0 0 20px;font-family:'Fraunces',Georgia,serif;font-size:15px;line-height:1.8;color:#3a3a3a;">
<li>Welcome reception with restaurant and hotel owners from across Houston</li>
<li>A working session on scaling profitably in 2026</li>
<li>An honest operator panel on growth, franchising, and the real numbers</li>
<li>Buffet dinner with curated room flow</li>
<li>The kind of conversations that turn rooms into networks</li>
</ul>
</div>
</td></tr>

<!-- ADD TO CALENDAR -->
<tr><td style="padding:0 40px 32px 40px;text-align:center;">
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.24em;color:#8b6f3a;text-transform:uppercase;margin-bottom:16px;">Don't Miss It</div>
<table role="presentation" cellpadding="0" cellspacing="0" align="center" style="margin:0 auto;"><tr>
<td style="padding:6px;vertical-align:middle;">
<a href="{{calendar_google_url}}" style="display:inline-block;background-color:#0a0a0a;color:#c9a55c;padding:14px 22px;text-decoration:none;font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.12em;text-transform:uppercase;border:1px solid #c9a55c;">Add to Google Calendar</a>
</td>
<td style="padding:6px;vertical-align:middle;">
<a href="{{calendar_ics_url}}" style="display:inline-block;background-color:#fdfaf3;color:#0a0a0a;padding:14px 22px;text-decoration:none;font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.12em;text-transform:uppercase;border:1px solid #c9a55c;">Apple / Outlook (.ics)</a>
</td>
</tr></table>
</td></tr>

<!-- CLOSING -->
<tr><td style="padding:0 40px 40px 40px;border-top:1px solid #e8dcc4;padding-top:32px;">
<p style="margin:0 0 12px 0;font-family:'Fraunces',Georgia,serif;font-size:16px;color:#3a3a3a;line-height:1.6;">Questions? Reply to this email or write to <a href="mailto:events@thehorecastore.com" style="color:#8b6f3a;">events@thehorecastore.com</a>.</p>
<p style="margin:0;font-family:'Fraunces',Georgia,serif;font-size:16px;font-style:italic;color:#0a0a0a;">We will see you at the table.</p>
<p style="margin:24px 0 0 0;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.1em;color:#8b6f3a;text-transform:uppercase;">Noman Peera<br><span style="color:#6b6b6b;">CEO · Horeca Store</span></p>
</td></tr>

<!-- ━━━ CANONICAL FOOTER ━━━ -->
<tr><td style="background-color:#0a0a0a;padding:36px 40px;text-align:center;">
<div style="font-family:'Fraunces',Georgia,serif;font-size:20px;font-weight:500;color:#ffffff;margin-bottom:8px;letter-spacing:-0.01em;">Horeca <em style="font-style:italic;color:#c9a55c;">Store</em></div>
<div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.2em;color:#a8a8a8;text-transform:uppercase;margin-bottom:24px;">Global Hospitality Supply · 11 Countries · 3 Continents</div>
<div style="font-family:'Fraunces',Georgia,serif;font-size:13px;font-style:italic;color:#a8a8a8;line-height:1.7;max-width:380px;margin:0 auto;">Trusted by 15,000+ hotels and restaurants across the Middle East, Asia, and the United States</div>
<div style="margin-top:28px;padding-top:24px;border-top:1px solid #2a2a2a;">
<a href="https://thehorecastore.com" style="font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.18em;color:#c9a55c;text-decoration:none;text-transform:uppercase;">thehorecastore.com</a>
<span style="color:#3a3a3a;margin:0 12px;">·</span>
<a href="mailto:events@thehorecastore.com" style="font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.18em;color:#c9a55c;text-decoration:none;text-transform:uppercase;">events@thehorecastore.com</a>
</div>
</td></tr>

</table>
<p style="margin:24px 0 0 0;font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.1em;color:#8b6f3a;text-align:center;text-transform:uppercase;">You are receiving this because {{host_first_name}} reserved a seat for you</p>
</td></tr></table>
</body></html>
$horeca_tpl$,
    updated_at = NOW()
WHERE slug = 'approval-plus-one';

COMMIT;
