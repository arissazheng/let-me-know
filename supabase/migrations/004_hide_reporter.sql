-- Let Me Know v2 — keep who filed a report private.
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.
--
-- Every signed-in student can still read every report (and get new ones live), but only the
-- report itself: the reporter's user_id can no longer be read through the API or the live
-- updates (Realtime leaves out columns the student isn't allowed to read).
-- The apps never read user_id, so they keep working unchanged.

revoke select on public.reports from anon, authenticated;

grant select (
  id, created_at, lat, lng, title, description, media, media_url, media_type, place_name,
  is_demo, demo_age
) on public.reports to authenticated;
