-- Let Me Know — Supabase schema
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.

create extension if not exists postgis;

-- ─── Incident reports (F3, F4) ─────────────────────────────────────────────
create table if not exists public.reports (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  user_id     uuid default auth.uid() references auth.users(id) on delete set null,
  lat         double precision not null,
  lng         double precision not null,
  description text not null check (char_length(description) between 1 and 1000),
  media_url   text,
  media_type  text check (media_type in ('image', 'video')),
  -- Seeded demo rows: always shown, displayed as `demo_age` old.
  is_demo     boolean not null default false,
  demo_age    interval
);

alter table public.reports enable row level security;

drop policy if exists "signed-in users read reports" on public.reports;
create policy "signed-in users read reports" on public.reports
  for select to authenticated using (true);

drop policy if exists "signed-in users file their own reports" on public.reports;
create policy "signed-in users file their own reports" on public.reports
  for insert to authenticated with check (user_id = auth.uid() and is_demo = false);

-- Reports from the last 24 hours. Reporter identity is not exposed.
create or replace view public.live_reports with (security_invoker = true) as
select id,
       lat,
       lng,
       description,
       media_url,
       media_type,
       case when is_demo then now() - demo_age else created_at end as created_at,
       is_demo
from public.reports
where is_demo or created_at > now() - interval '24 hours';

grant select on public.live_reports to authenticated;

-- Live updates for route self-correction (F8)
alter publication supabase_realtime add table public.reports;

-- ─── Report media (images / videos) ───────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('report-media', 'report-media', true)
on conflict (id) do nothing;

drop policy if exists "signed-in users upload report media" on storage.objects;
create policy "signed-in users upload report media" on storage.objects
  for insert to authenticated with check (bucket_id = 'report-media');

-- ─── Preference-based location pings → population glow ───────────────────
create table if not exists public.location_pings (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  user_id    uuid default auth.uid() references auth.users(id) on delete cascade,
  lat        double precision not null,
  lng        double precision not null,
  simulated  boolean not null default false
);

alter table public.location_pings enable row level security;

-- Users can add their own pings but nobody can read individual pings.
drop policy if exists "signed-in users add their own pings" on public.location_pings;
create policy "signed-in users add their own pings" on public.location_pings
  for insert to authenticated with check (user_id = auth.uid() and simulated = false);

-- Aggregated density (~11 m cells): real pings from the last 30 minutes plus simulated seed pings.
create or replace function public.population_cells()
returns table (lat double precision, lng double precision, weight integer)
language sql
security definer
set search_path = public
stable
as $$
  select round(lat::numeric, 4)::double precision,
         round(lng::numeric, 4)::double precision,
         count(*)::integer
  from public.location_pings
  where simulated or created_at > now() - interval '30 minutes'
  group by 1, 2;
$$;

revoke all on function public.population_cells() from public, anon;
grant execute on function public.population_cells() to authenticated;
