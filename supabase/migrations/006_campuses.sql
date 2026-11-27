-- Let Me Know v3 — any school's students, each campus with its own reports and safety resources.
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.
--
-- A student's campus is their email's school domain (jane@g.ucla.edu → ucla.edu). Signing in with
-- a .edu Google account from a school we haven't seen adds that campus here as 'pending'; the
-- campus-info Edge Function then looks up its name, location, and safety resources.

-- ─── Campuses ──────────────────────────────────────────────────────────────
create table if not exists public.campuses (
  domain       text primary key,
  name         text,                -- "University of California, Berkeley"
  short_name   text,                -- "UC Berkeley"
  lat          double precision,    -- center of the main campus
  lng          double precision,
  police_name  text,                -- short name for the + button, e.g. "UCPD"
  police_phone text,                -- campus police emergency line (digits)
  -- [{ title, footer, items: [{ label, detail, phone, url, source_url }] }]
  resources    jsonb not null default '[]',
  status       text not null default 'pending' check (status in ('pending', 'generating', 'ready', 'failed')),
  updated_at   timestamptz not null default now()
);

alter table public.campuses enable row level security;
drop policy if exists "signed-in students read campuses" on public.campuses;
create policy "signed-in students read campuses" on public.campuses for select to authenticated using (true);
grant select on public.campuses to authenticated;

-- jane@g.ucla.edu → ucla.edu; null for non-.edu addresses.
create or replace function public.campus_of(email text)
returns text language sql immutable
as $$ select lower(substring(email from '([A-Za-z0-9-]+\.edu)$')) $$;

-- The signed-in student's campus.
create or replace function public.my_campus()
returns text language sql stable
as $$ select public.campus_of(auth.jwt() ->> 'email') $$;

-- Only school (.edu) accounts can be created, and each new school gets a campus row.
create or replace function public.register_campus()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if public.campus_of(new.email) is null then
    raise exception 'Sign in with your school (.edu) Google account.';
  end if;
  insert into public.campuses (domain) values (public.campus_of(new.email)) on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists register_campus on auth.users;
create trigger register_campus
  before insert or update of email on auth.users
  for each row execute function public.register_campus();

-- Lets the campus-info Edge Function claim a campus to research, so two first sign-ups at the same
-- school don't both run the lookup. A lookup stuck for 10 minutes, or one that failed, can be retried.
create or replace function public.claim_campus(target text)
returns boolean language sql security definer set search_path = public
as $$
  with claimed as (
    update public.campuses set status = 'generating', updated_at = now()
    where domain = target
      and (status in ('pending', 'failed') or (status = 'generating' and updated_at < now() - interval '10 minutes'))
    returning 1
  )
  select exists (select 1 from claimed)
$$;
revoke all on function public.claim_campus(text) from public, anon, authenticated;
grant execute on function public.claim_campus(text) to service_role;

-- ─── Reports belong to a campus ───────────────────────────────────────────
alter table public.reports add column if not exists campus text;
update public.reports set campus = 'berkeley.edu' where campus is null; -- everything so far
alter table public.reports alter column campus set default public.my_campus();
alter table public.reports alter column campus set not null;
grant select (campus) on public.reports to authenticated;

-- Students only read, and only file, reports for their own campus. live_reports and all_reports
-- run as the student, so they follow this too, and so do live updates.
drop policy if exists "signed-in users read reports" on public.reports;
drop policy if exists "students read their campus's reports" on public.reports;
create policy "students read their campus's reports" on public.reports
  for select to authenticated using (campus = public.my_campus());

drop policy if exists "signed-in users file their own reports" on public.reports;
create policy "signed-in users file their own reports" on public.reports
  for insert to authenticated with check (user_id = auth.uid() and is_demo = false and campus = public.my_campus());

-- ─── UC Berkeley, the first campus ────────────────────────────────────────
insert into public.campuses (domain, name, short_name, lat, lng, police_name, police_phone, status, resources)
values (
  'berkeley.edu', 'University of California, Berkeley', 'UC Berkeley', 37.8690, -122.2595, 'UCPD', '5106423333', 'ready',
  $json$[
    {"title": "Emergency", "footer": "Blue light phones on campus also connect straight to UCPD dispatch.", "items": [
      {"label": "Emergency", "detail": "911", "phone": "911", "url": null, "source_url": null},
      {"label": "UCPD Emergency from a Cell Phone", "detail": "(510) 642-3333", "phone": "5106423333", "url": null, "source_url": "https://ucpd.berkeley.edu/node/693"}
    ]},
    {"title": "UCPD Resources", "footer": null, "items": [
      {"label": "UCPD Non-Emergency (24 hours)", "detail": "(510) 642-6760", "phone": "5106426760", "url": null, "source_url": "https://ucpd.berkeley.edu/node/693"},
      {"label": "SafeWalk Escort", "detail": "Dusk – 3 AM, last call 2:30 AM · (510) 642-WALK", "phone": "5106429255", "url": null, "source_url": "https://nightsafety.berkeley.edu/"},
      {"label": "Night Safety Shuttle", "detail": "7:30 PM – 3 AM · book in the Downtowner app", "phone": null, "url": "https://nightsafety.berkeley.edu/", "source_url": "https://nightsafety.berkeley.edu/"},
      {"label": "Make a Report to UCPD", "detail": "ucpd.berkeley.edu", "phone": null, "url": "https://ucpd.berkeley.edu/make-report", "source_url": "https://ucpd.berkeley.edu/make-report"},
      {"label": "Resource Guide", "detail": "Campus safety support", "phone": null, "url": "https://supportal.berkeley.edu/topics/safety", "source_url": "https://supportal.berkeley.edu/topics/safety"}
    ]},
    {"title": "Anonymous Tips", "footer": null, "items": [
      {"label": "CalTIP (text)", "detail": "(510) 664-8477 · non-emergency crime", "phone": null, "url": "sms:5106648477", "source_url": "https://ucpd.berkeley.edu/node/693"}
    ]},
    {"title": "City of Berkeley", "footer": null, "items": [
      {"label": "Berkeley Police Non-Emergency", "detail": "(510) 981-5900", "phone": "5109815900", "url": null, "source_url": null}
    ]}
  ]$json$::jsonb
)
on conflict (domain) do update set
  name = excluded.name, short_name = excluded.short_name, lat = excluded.lat, lng = excluded.lng,
  police_name = excluded.police_name, police_phone = excluded.police_phone,
  resources = excluded.resources, status = 'ready', updated_at = now();
