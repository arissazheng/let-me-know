-- Let Me Know — demo data. Run after schema.sql (SQL Editor → paste → Run).
-- Safe to re-run: clears previous demo rows first.

delete from public.reports where is_demo;
delete from public.location_pings where simulated;

-- Demo reports, drawn from Team 14's interviews and observations.
insert into public.reports (lat, lng, description, is_demo, demo_age) values
  (37.86730, -122.25885, 'Man with a bullwhip near the apartments on Telegraph. Called the police.', true, interval '25 minutes'),
  (37.86795, -122.25900, 'A man shoved a student walking to campus on Telegraph.', true, interval '2 hours'),
  (37.86880, -122.25905, 'Man punched an elderly woman in the face near Telegraph & Bancroft.', true, interval '5 hours'),
  (37.86860, -122.25490, 'Man followed a student into a cafe on College and tried to follow her into the bathroom.', true, interval '8 hours'),
  (37.86590, -122.25890, 'Guy staring and making unwanted comments at people walking past on Haste.', true, interval '50 minutes'),
  (37.86510, -122.25850, 'Group yelling at people walking by on Dwight. Walked home with a friend instead.', true, interval '11 hours');

-- Simulated population pings (labeled "simulated" in the app).
-- Dense: Telegraph, Bancroft, Sproul Plaza, Durant. Sparse: side streets.
insert into public.location_pings (lat, lng, simulated)
select 37.8650 + random() * 0.0040, -122.2590 + (random() - 0.5) * 0.0004, true from generate_series(1, 120)   -- Telegraph
union all
select 37.8688 + (random() - 0.5) * 0.0004, -122.2660 + random() * 0.0130, true from generate_series(1, 120)   -- Bancroft
union all
select 37.8696 + random() * 0.0009, -122.2595 + random() * 0.0010, true from generate_series(1, 80)            -- Sproul Plaza
union all
select 37.8679 + (random() - 0.5) * 0.0004, -122.2650 + random() * 0.0110, true from generate_series(1, 60)    -- Durant
union all
select 37.8620 + random() * 0.0130, -122.2680 + random() * 0.0180, true from generate_series(1, 60);          -- scattered
