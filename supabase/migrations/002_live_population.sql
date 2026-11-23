-- Let Me Know — live population density.
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.
--
-- Count each student once, at their most recent location from the last 10 minutes,
-- instead of counting every ping (which made one person walking for 30 minutes look
-- like a crowd smeared along their path). Simulated seed pings are still included.

create index if not exists location_pings_user_recent
  on public.location_pings (user_id, created_at desc)
  where not simulated;

create or replace function public.population_cells()
returns table (lat double precision, lng double precision, weight integer)
language sql
security definer
set search_path = public
stable
as $$
  with live as (
    select distinct on (user_id) lat, lng
    from public.location_pings
    where not simulated and created_at > now() - interval '10 minutes'
    order by user_id, created_at desc
  ),
  points as (
    select lat, lng from live
    union all
    select lat, lng from public.location_pings where simulated
  )
  select round(lat::numeric, 4)::double precision,
         round(lng::numeric, 4)::double precision,
         count(*)::integer
  from points
  group by 1, 2;
$$;

revoke all on function public.population_cells() from public, anon;
grant execute on function public.population_cells() to authenticated;
