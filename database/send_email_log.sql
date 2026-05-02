-- send_email_log: forensic record of every send-registration-email invocation.
-- Captures the exact error if Resend rejects, function crashes, or any other failure mode
-- so we can never have a silent failure again.

CREATE TABLE IF NOT EXISTS public.send_email_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id UUID,
  template_id     UUID,
  template_slug   TEXT,
  action_type     TEXT,
  recipient_email TEXT,
  recipient_type  TEXT,
  attempt_number  INT NOT NULL DEFAULT 1,
  outcome         TEXT NOT NULL,                  -- 'ok' | 'retrying' | 'failed' | 'crashed'
  http_status     INT,
  error_phase     TEXT,
  error_detail    TEXT,
  resend_email_id TEXT,
  duration_ms     INT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_send_email_log_reg
  ON public.send_email_log (registration_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_send_email_log_outcome
  ON public.send_email_log (outcome, created_at DESC);

ALTER TABLE public.send_email_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS send_email_log_admin_read ON public.send_email_log;
CREATE POLICY send_email_log_admin_read
  ON public.send_email_log
  FOR SELECT
  TO authenticated
  USING (true);

GRANT SELECT ON public.send_email_log TO anon, authenticated;
