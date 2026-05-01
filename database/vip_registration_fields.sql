-- VIP apply page: optional narrative + program-interest flags (run in Supabase SQL Editor).
-- If this is not run, the public form still saves (fallback) into `challenge` and may omit `is_vip` if RLS blocks it.
ALTER TABLE public.registrations
  ADD COLUMN IF NOT EXISTS vip_optional_note text,
  ADD COLUMN IF NOT EXISTS vip_interest_keynote boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS vip_interest_qa boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS vip_topic_note text;

COMMENT ON COLUMN public.registrations.vip_optional_note IS 'VIP apply: optional context before the evening (replaces challenge for VIP path)';
COMMENT ON COLUMN public.registrations.vip_interest_keynote IS 'VIP apply: considered for keynote / featured remarks';
COMMENT ON COLUMN public.registrations.vip_interest_qa IS 'VIP apply: considered for audience Q&A';
COMMENT ON COLUMN public.registrations.vip_topic_note IS 'VIP apply: optional topic or angle';
