-- Let Me Know v2 — things that follow a student's account, and their own reports.
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.

-- Favorite places, recent searches, and settings, so signing back in with the same email on any
-- phone or browser brings them back. Each student can only read and change their own row.
create table if not exists public.user_data (
  user_id     uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  favorites   jsonb not null default '[]',
  recents     jsonb not null default '[]',
  preferences jsonb not null default '{}',
  updated_at  timestamptz not null default now()
);

alter table public.user_data enable row level security;

drop policy if exists "students manage their own data" on public.user_data;
create policy "students manage their own data" on public.user_data
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update on public.user_data to authenticated;

-- "My Reports" in the Incident Tracker. Students can't read user_id (004_hide_reporter.sql), so
-- this view does the matching itself and returns only the signed-in student's own reports,
-- without the user_id column.
create or replace view public.my_reports as
select id, lat, lng, description, media_url, media_type, created_at, is_demo, title, media, place_name
from public.reports
where user_id = auth.uid();

revoke all on public.my_reports from anon;
grant select on public.my_reports to authenticated;

-- "All Reports" in the Incident Tracker: every report, not just the last 24 hours, with demo rows
-- dated the same way as on the map (live_reports in 003_v2_reports.sql).
create or replace view public.all_reports with (security_invoker = true) as
select id, lat, lng, description, media_url, media_type,
       case when is_demo then now() - demo_age else created_at end as created_at,
       is_demo, title, media, place_name
from public.reports;

revoke all on public.all_reports from anon;
grant select on public.all_reports to authenticated;
