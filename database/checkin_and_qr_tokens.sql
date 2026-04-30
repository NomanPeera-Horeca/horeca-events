-- Check-in columns + QR token columns + indexes + admin RLS helpers
-- Run in Supabase SQL Editor (Dashboard → SQL → New query).

-- ─── Columns ─────────────────────────────────────────────────────────
ALTER TABLE public.registrations
  ADD COLUMN IF NOT EXISTS qr_token text,
  ADD COLUMN IF NOT EXISTS plus_one_qr_token text,
  ADD COLUMN IF NOT EXISTS plus_one_qr_code_url text,
  ADD COLUMN IF NOT EXISTS checked_in_at timestamptz,
  ADD COLUMN IF NOT EXISTS checked_in_by text,
  ADD COLUMN IF NOT EXISTS plus_one_checked_in_at timestamptz,
  ADD COLUMN IF NOT EXISTS plus_one_checked_in_by text;

CREATE INDEX IF NOT EXISTS idx_registrations_qr_token ON public.registrations (qr_token);
CREATE INDEX IF NOT EXISTS idx_registrations_plus_one_qr_token ON public.registrations (plus_one_qr_token);

-- One registration per token (tokens are NULL until approve edge function runs)
CREATE UNIQUE INDEX IF NOT EXISTS uq_registrations_qr_token
  ON public.registrations (qr_token)
  WHERE qr_token IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_registrations_plus_one_qr_token
  ON public.registrations (plus_one_qr_token)
  WHERE plus_one_qr_token IS NOT NULL;

-- ─── RLS: admins (rows in admin_users, matched by auth JWT email) ───
-- Skip if you already have equivalent policies (list policies on registrations / activity_log first).

CREATE POLICY "horeca_admin_select_registrations"
  ON public.registrations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE lower(au.email) = lower(auth.jwt() ->> 'email')
    )
  );

CREATE POLICY "horeca_admin_update_registrations"
  ON public.registrations
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE lower(au.email) = lower(auth.jwt() ->> 'email')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE lower(au.email) = lower(auth.jwt() ->> 'email')
    )
  );

CREATE POLICY "horeca_admin_insert_activity_log"
  ON public.activity_log
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE lower(au.email) = lower(auth.jwt() ->> 'email')
    )
  );

CREATE POLICY "horeca_admin_select_activity_log"
  ON public.activity_log
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE lower(au.email) = lower(auth.jwt() ->> 'email')
    )
  );

-- Realtime: Dashboard → Database → Replication → enable `registrations` (and `activity_log` if you want).
