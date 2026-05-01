#!/usr/bin/env node
/**
 * Import registrations exported from Google Sheets / Drive (CSV) into Supabase `registrations`.
 *
 * Prereqs:
 *   1. In Google Sheets: File → Download → Comma separated values (.csv)
 *   2. Supabase → Settings → API: Project URL + service_role key (never commit the key; never use in browser)
 *
 * Usage:
 *   cd /path/to/Horeca_Events && npm install
 *   export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
 *   export SUPABASE_SERVICE_ROLE_KEY="eyJ..."
 *   node scripts/import-registrations-from-csv.mjs path/to/export.csv
 *
 * Options:
 *   --dry-run              Print rows only; no DB writes
 *   --event-slug=SLUG      Default: houston-vol-2-may-2026
 *   --status=pending|approved|rejected|needs_info
 *   --vip                  Set is_vip true on imported rows
 *   --default-phone=TEL    When CSV has no phone column / empty value
 *
 * Column headers are matched flexibly (case/spacing insensitive), e.g.:
 *   First Name, Last Name, Email, Phone, Business, Company, Role, Locations, Notes, Source
 *
 * Rows with the same email as an existing registration for that event are skipped.
 */

import { createClient } from "@supabase/supabase-js";
import fs from "fs";
import path from "path";

function parseArgs(argv) {
  const out = {
    file: null,
    dryRun: false,
    eventSlug: "houston-vol-2-may-2026",
    status: "pending",
    vip: false,
    defaultPhone: null,
  };
  for (const a of argv) {
    if (a === "--dry-run") out.dryRun = true;
    else if (a.startsWith("--event-slug="))
      out.eventSlug = a.slice("--event-slug=".length);
    else if (a.startsWith("--status=")) out.status = a.slice("--status=".length);
    else if (a === "--vip") out.vip = true;
    else if (a.startsWith("--default-phone="))
      out.defaultPhone = a.slice("--default-phone=".length);
    else if (!a.startsWith("-") && !out.file) out.file = a;
  }
  return out;
}

/** Minimal RFC4180-style CSV parse (quoted fields, commas). */
function parseCsv(text) {
  const rows = [];
  let row = [];
  let cur = "";
  let inQ = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQ) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          cur += '"';
          i++;
        } else inQ = false;
      } else cur += c;
    } else {
      if (c === '"') inQ = true;
      else if (c === ",") {
        row.push(cur);
        cur = "";
      } else if (c === "\n" || c === "\r") {
        if (c === "\r" && text[i + 1] === "\n") i++;
        row.push(cur);
        cur = "";
        if (row.some((x) => String(x).length > 0)) rows.push(row);
        row = [];
      } else cur += c;
    }
  }
  row.push(cur);
  if (row.some((x) => String(x).length > 0)) rows.push(row);
  return rows;
}

function normKey(h) {
  return String(h ?? "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ")
    .replace(/[^a-z0-9\s]/g, "")
    .replace(/\s+/g, "_");
}

/** Map normalized header → canonical field */
function headerToField(n) {
  const aliases = [
    ["first_name", ["first_name", "firstname", "first", "given_name", "givenname", "fname"]],
    ["last_name", ["last_name", "lastname", "last", "surname", "family_name", "lname"]],
    ["email", ["email", "e_mail", "email_address"]],
    ["phone", ["phone", "mobile", "whatsapp", "tel", "telephone", "cell"]],
    ["business_name", ["business_name", "business", "company", "restaurant", "organization", "org"]],
    ["role", ["role", "title", "job_title", "position"]],
    ["locations", ["locations", "location", "units", "of_locations"]],
    ["challenge", ["notes", "note", "comments", "challenge", "message", "details"]],
    ["source", ["source", "referral", "heard_from", "how_heard"]],
    ["plus_one_first_name", ["guest_first", "plus_one_first_name", "plusone_first"]],
    ["plus_one_last_name", ["guest_last", "plus_one_last_name", "plusone_last"]],
    ["plus_one_email", ["guest_email", "plus_one_email", "plusone_email"]],
    ["plus_one_phone", ["guest_phone", "plus_one_phone", "plusone_phone"]],
  ];
  for (const [field, keys] of aliases) {
    if (keys.includes(n)) return field;
  }
  return null;
}

function rowsToObjects(headerRow, dataRows) {
  const headers = headerRow.map((h) => normKey(h));
  const fields = headers.map(headerToField);
  return dataRows.map((cells) => {
    const o = {};
    for (let i = 0; i < fields.length; i++) {
      const f = fields[i];
      if (!f) continue;
      const v = cells[i] != null ? String(cells[i]).trim() : "";
      if (v !== "") o[f] = v;
    }
    return o;
  });
}

function buildRegistration(row, eventId, opts) {
  const email = (row.email || "").toLowerCase().trim();
  const first = (row.first_name || "").trim();
  const last = (row.last_name || "").trim();
  if (!email || !first || !last) return { error: "missing email, first_name, or last_name" };

  const phone = (row.phone || "").trim() || opts.defaultPhone || null;
  const hasPlus =
    !!(row.plus_one_email && String(row.plus_one_email).trim()) ||
    !!(row.plus_one_first_name && String(row.plus_one_first_name).trim());

  const reg = {
    event_id: eventId,
    form_type: "rsvp",
    status: opts.status,
    first_name: first,
    last_name: last,
    email,
    phone,
    business_name: (row.business_name || "").trim() || null,
    role: (row.role || "").trim() || null,
    locations: (row.locations || "").trim() || null,
    challenge: (row.challenge || "").trim() || null,
    source: (row.source || "").trim() || "Google Drive / Sheet import",
    has_plus_one: hasPlus,
    plus_one_first_name: hasPlus
      ? (row.plus_one_first_name || "").trim() || null
      : null,
    plus_one_last_name: hasPlus
      ? (row.plus_one_last_name || "").trim() || null
      : null,
    plus_one_email: hasPlus
      ? (row.plus_one_email || "").toLowerCase().trim() || null
      : null,
    plus_one_phone: hasPlus ? (row.plus_one_phone || "").trim() || null : null,
    plus_one_role: null,
    attendee_count: hasPlus ? 2 : 1,
    is_vip: opts.vip,
    user_agent: "import/google-drive-csv",
    utm_source: null,
    utm_medium: null,
    utm_campaign: null,
  };
  return { registration: reg };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.file) {
    console.error(
      "Usage: node scripts/import-registrations-from-csv.mjs [--dry-run] [--event-slug=...] [--status=pending] [--vip] [--default-phone=...] path/to/file.csv",
    );
    process.exit(1);
  }

  const url = process.env.SUPABASE_URL?.trim();
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!args.dryRun && (!url || !key)) {
    console.error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (service role, not anon).");
    process.exit(1);
  }

  const fp = path.resolve(args.file);
  if (!fs.existsSync(fp)) {
    console.error("File not found:", fp);
    process.exit(1);
  }

  const raw = fs.readFileSync(fp, "utf8");
  const grid = parseCsv(raw.replace(/^\uFEFF/, ""));
  if (grid.length < 2) {
    console.error("CSV must have a header row and at least one data row.");
    process.exit(1);
  }
  const objects = rowsToObjects(grid[0], grid.slice(1));

  const supabase =
    url && key
      ? createClient(url, key, {
          auth: { persistSession: false, autoRefreshToken: false },
        })
      : null;

  let eventId;
  if (supabase) {
    const { data: ev, error: evErr } = await supabase
      .from("events")
      .select("id")
      .eq("slug", args.eventSlug)
      .maybeSingle();
    if (evErr || !ev?.id) {
      console.error("Could not find event with slug:", args.eventSlug, evErr?.message || "");
      process.exit(1);
    }
    eventId = ev.id;
  }

  const existingEmails = new Set();
  if (supabase && eventId) {
    const { data: regs, error: rErr } = await supabase
      .from("registrations")
      .select("email")
      .eq("event_id", eventId);
    if (rErr) {
      console.error("Could not load existing registrations:", rErr.message);
      process.exit(1);
    }
    for (const r of regs || []) {
      if (r.email) existingEmails.add(String(r.email).toLowerCase().trim());
    }
  }

  let ok = 0;
  let skipped = 0;
  let failed = 0;

  for (let i = 0; i < objects.length; i++) {
    const built = buildRegistration(objects[i], eventId, args);
    if (built.error) {
      console.warn(`Row ${i + 2}: skip — ${built.error}`, objects[i]);
      skipped++;
      continue;
    }
    const reg = built.registration;
    if (existingEmails.has(reg.email)) {
      console.warn(`Row ${i + 2}: skip — duplicate email ${reg.email}`);
      skipped++;
      continue;
    }

    if (args.dryRun) {
      console.log(JSON.stringify(reg, null, 2));
      ok++;
      continue;
    }

    const { error: insErr } = await supabase.from("registrations").insert([reg]);
    if (insErr) {
      console.error(`Row ${i + 2}: insert failed`, insErr.message, reg.email);
      failed++;
      continue;
    }
    existingEmails.add(reg.email);
    ok++;
  }

  console.log(
    `\nDone. inserted=${ok} skipped=${skipped} failed=${failed} dry_run=${args.dryRun}`,
  );
  if (failed > 0) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
