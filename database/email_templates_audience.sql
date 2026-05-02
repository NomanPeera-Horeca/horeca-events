-- Adds an `audience` tag to email_templates so the admin UI can show only
-- the right templates for each per-row action.
--
--   primary       → goes to the main attendee (e.g. approval, approval-vip)
--   plus_one      → goes to the +1 (e.g. approval-plus-one)
--   manual_only   → reserved for cron/system actions (reminders, day-of) but
--                   selectable by admin in the relevant action picker
--   system        → never user-selectable

ALTER TABLE public.email_templates
  ADD COLUMN IF NOT EXISTS audience TEXT;

UPDATE public.email_templates SET audience = 'primary'
  WHERE slug IN ('approval', 'approval-vip')
  AND audience IS NULL;

UPDATE public.email_templates SET audience = 'plus_one'
  WHERE slug IN ('approval-plus-one')
  AND audience IS NULL;

UPDATE public.email_templates SET audience = 'manual_only'
  WHERE slug LIKE 'reminder-%'
  AND audience IS NULL;

UPDATE public.email_templates SET audience = 'manual_only'
  WHERE slug LIKE 'rejection-%' OR slug LIKE 'question-%'
  AND audience IS NULL;

UPDATE public.email_templates SET audience = 'manual_only'
  WHERE audience IS NULL;

ALTER TABLE public.email_templates
  ALTER COLUMN audience SET DEFAULT 'manual_only';

ALTER TABLE public.email_templates
  ALTER COLUMN audience SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_email_templates_audience
  ON public.email_templates (audience);
