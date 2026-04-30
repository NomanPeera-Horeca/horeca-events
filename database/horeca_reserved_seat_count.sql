-- Run once in Supabase → SQL Editor.
-- Lets the public site (anon key) read an aggregate seat count without exposing registration rows.
-- Without this, RLS usually blocks SELECT on registrations → the hero counter stays stuck at the marketing floor.

create or replace function public.horeca_reserved_seat_count(p_event_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    sum(
      case
        when r.attendee_count is null or r.attendee_count < 1 then 1
        else r.attendee_count::integer
      end
    ),
    0
  )::integer
  from public.registrations r
  where r.event_id = p_event_id
    and coalesce(r.status, '') <> 'rejected';
$$;

revoke all on function public.horeca_reserved_seat_count(uuid) from public;
grant execute on function public.horeca_reserved_seat_count(uuid) to anon, authenticated;
