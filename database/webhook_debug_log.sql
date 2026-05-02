-- Diagnostic log for the resend-webhook Edge Function. Writes one row per
-- inbound HTTP hit BEFORE any signature / tag checks, so we can see exactly
-- what's arriving (or confirm nothing is). Safe to DROP once the live webhook
-- is confirmed flowing.
CREATE TABLE IF NOT EXISTS public.webhook_debug_log (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  arrived_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  phase             TEXT NOT NULL,           -- 'entry' | 'sig_ok' | 'sig_fail' | 'skip_untagged' | 'insert_ok' | 'insert_fail' | 'recompute_err'
  http_status       INTEGER,
  note              TEXT,
  method            TEXT,
  user_agent        TEXT,
  svix_id           TEXT,
  svix_timestamp    TEXT,
  resend_event_type TEXT,
  body_preview      TEXT
);
GRANT SELECT ON public.webhook_debug_log TO authenticated;
