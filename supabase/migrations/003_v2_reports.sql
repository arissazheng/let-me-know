-- Let Me Know v2 — report titles, multiple photos/videos, and a place name.
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.
--
-- Additive only, so the v1 apps keep working: v1 still reads media_url / media_type,
-- which v2 fills with the first attachment.

alter table public.reports
  add column if not exists title text check (title is null or char_length(title) between 1 and 120),
  -- [{ "url": "...", "type": "image" | "video" }, …]
  add column if not exists media jsonb not null default '[]'::jsonb,
  -- Street the report is on (e.g. "University Avenue"), looked up when it's filed.
  add column if not exists place_name text;

-- New columns go at the end so the view keeps v1's column order.
create or replace view public.live_reports with (security_invoker = true) as
select id,
       lat,
       lng,
       description,
       media_url,
       media_type,
       case when is_demo then now() - demo_age else created_at end as created_at,
       is_demo,
       title,
       media,
       place_name
from public.reports
where is_demo or created_at > now() - interval '24 hours';

grant select on public.live_reports to authenticated;

-- Titles and places for the seeded demo reports.
update public.reports set title = 'Man with a bullwhip',        place_name = 'Telegraph Avenue'  where is_demo and description like 'Man with a bullwhip%';
update public.reports set title = 'Student shoved',             place_name = 'Telegraph Avenue'  where is_demo and description like 'A man shoved%';
update public.reports set title = 'Assault',                    place_name = 'Telegraph & Bancroft' where is_demo and description like 'Man punched%';
update public.reports set title = 'Being followed',             place_name = 'College Avenue'    where is_demo and description like 'Man followed%';
update public.reports set title = 'Unwanted comments',          place_name = 'Haste Street'      where is_demo and description like 'Guy staring%';
update public.reports set title = 'Yelling at passersby',       place_name = 'Dwight Way'        where is_demo and description like 'Group yelling%';
