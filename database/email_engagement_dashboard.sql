-- ═══════════════════════════════════════════════════════════════════════════
-- Email Engagement Dashboard · Schema Migration
-- PRD v2.0 FINAL · Section 7
-- ═══════════════════════════════════════════════════════════════════════════
-- Creates the email_events log table, per-registration aggregate column,
-- and the two views that power the Mailchimp-style engagement dashboard.
-- Idempotent: safe to run multiple times.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ───── 7.1  email_events  ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.email_events (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id      UUID REFERENCES public.registrations(id) ON DELETE CASCADE,
  resend_email_id      TEXT NOT NULL,
  email_template_slug  TEXT NOT NULL,
  event_type           TEXT NOT NULL,
  recipient_type       TEXT,                      -- 'main' | 'plus_one'
  recipient_email      TEXT,
  occurred_at          TIMESTAMPTZ NOT NULL,
  link_url             TEXT,                      -- for clicked events
  ip_address           INET,                      -- forensic forwarding
  user_agent           TEXT,                      -- forensic forwarding
  city                 TEXT,
  country              TEXT,
  raw_payload          JSONB,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ee_registration ON public.email_events(registration_id);
CREATE INDEX IF NOT EXISTS idx_ee_template     ON public.email_events(email_template_slug);
CREATE INDEX IF NOT EXISTS idx_ee_type         ON public.email_events(event_type);
CREATE INDEX IF NOT EXISTS idx_ee_occurred     ON public.email_events(occurred_at DESC);

-- Dedup: Resend retries duplicates
CREATE UNIQUE INDEX IF NOT EXISTS idx_ee_dedup
  ON public.email_events(resend_email_id, event_type, occurred_at);

-- ───── RLS on email_events  ──────────────────────────────────────────────
-- Read-only for authenticated admins (aligns with other engagement views);
-- writes only via service role (Edge Function).
ALTER TABLE public.email_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "email_events_admin_read" ON public.email_events;
CREATE POLICY "email_events_admin_read"
  ON public.email_events
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE lower(au.email) = lower(auth.jwt() ->> 'email')
    )
  );

-- ───── 7.2  registrations.email_engagement  ──────────────────────────────
ALTER TABLE public.registrations
  ADD COLUMN IF NOT EXISTS email_engagement JSONB NOT NULL DEFAULT '{}'::jsonb;

-- ───── 7.3  v_recipient_engagement  ──────────────────────────────────────
DROP VIEW IF EXISTS public.v_recipient_engagement CASCADE;
CREATE VIEW public.v_recipient_engagement AS
SELECT
  r.id                                  AS registration_id,
  TRIM(CONCAT_WS(' ', r.first_name, r.last_name)) AS full_name,
  r.email                               AS email,
  r.business_name                       AS business_name,
  r.role                                AS role_title,
  r.event_id                            AS event_id,
  ee.email_template_slug                AS email_template_slug,
  BOOL_OR(ee.event_type = 'delivered')  AS delivered,
  BOOL_OR(ee.event_type = 'opened')     AS opened,
  COUNT(*) FILTER (WHERE ee.event_type = 'opened')::int  AS open_count,
  COUNT(*) FILTER (WHERE ee.event_type = 'clicked')::int AS click_count,
  BOOL_OR(ee.event_type = 'bounced')    AS bounced,
  BOOL_OR(
    ee.event_type = 'clicked' AND (
      ee.link_url ILIKE '%calendar.google.com%' OR
      ee.link_url ILIKE '%/calendar.html%'      OR
      ee.link_url ILIKE '%calendar.ics%'
    )
  ) AS calendar_added,
  COUNT(DISTINCT ee.city)       FILTER (WHERE ee.event_type = 'opened')::int AS unique_cities,
  COUNT(DISTINCT ee.ip_address) FILTER (WHERE ee.event_type = 'opened')::int AS unique_ips,
  COUNT(DISTINCT ee.user_agent) FILTER (WHERE ee.event_type = 'opened')::int AS unique_devices,
  MIN(ee.occurred_at) FILTER (WHERE ee.event_type = 'sent')      AS sent_at,
  MAX(ee.occurred_at) AS last_activity,
  CASE
    WHEN COUNT(DISTINCT ee.city)       FILTER (WHERE ee.event_type = 'opened') >= 2 THEN 'yes'
    WHEN COUNT(DISTINCT ee.ip_address) FILTER (WHERE ee.event_type = 'opened') >= 3 THEN 'yes'
    WHEN COUNT(DISTINCT ee.user_agent) FILTER (WHERE ee.event_type = 'opened') >= 3 THEN 'maybe'
    ELSE NULL
  END AS forwarded_status
FROM public.registrations r
JOIN public.email_events   ee ON ee.registration_id = r.id
WHERE ee.email_template_slug IS NOT NULL
GROUP BY
  r.id, r.first_name, r.last_name, r.email, r.business_name, r.role, r.event_id,
  ee.email_template_slug;

-- ───── 7.4  v_campaign_summary  ──────────────────────────────────────────
DROP VIEW IF EXISTS public.v_campaign_summary CASCADE;
CREATE VIEW public.v_campaign_summary AS
SELECT
  event_id,
  email_template_slug,
  COUNT(DISTINCT registration_id)                                          AS sent_count,
  COUNT(DISTINCT registration_id) FILTER (WHERE delivered)                 AS delivered_count,
  COUNT(DISTINCT registration_id) FILTER (WHERE opened)                    AS opened_count,
  COUNT(DISTINCT registration_id) FILTER (WHERE click_count > 0)           AS clicked_count,
  COUNT(DISTINCT registration_id) FILTER (WHERE calendar_added)            AS cal_added_count,
  COUNT(DISTINCT registration_id) FILTER (WHERE forwarded_status IS NOT NULL) AS forwarded_count,
  COUNT(DISTINCT registration_id) FILTER (WHERE bounced)                   AS bounced_count,
  MAX(last_activity)                                                       AS last_activity,
  MIN(sent_at)                                                             AS first_sent_at
FROM public.v_recipient_engagement
GROUP BY event_id, email_template_slug;

-- Grant read access to both views for the anon/authenticated API roles so the
-- dashboard (signed-in admins) can query them via supabase-js.
GRANT SELECT ON public.v_recipient_engagement TO anon, authenticated;
GRANT SELECT ON public.v_campaign_summary     TO anon, authenticated;
GRANT SELECT ON public.email_events            TO authenticated;

-- ───── Realtime: include email_events in supabase_realtime publication ───
-- Step 8 of Section 10. Idempotent.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'email_events'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.email_events';
  END IF;
END$$;

COMMIT;
