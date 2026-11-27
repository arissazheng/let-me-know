-- Let Me Know v3 — only UC Berkeley accounts, whichever way students sign in.
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.
--
-- v3 signs in with Google. The apps ask Google for a berkeley.edu account, but anyone can edit that
-- request, so the database itself refuses to create an account for any other email.

create or replace function public.require_campus_email()
returns trigger
language plpgsql
as $$
begin
  if new.email is null or lower(new.email) not like '%@berkeley.edu' then
    raise exception 'Only @berkeley.edu accounts can sign in to Let Me Know.';
  end if;
  return new;
end;
$$;

drop trigger if exists require_campus_email on auth.users;
create trigger require_campus_email
  before insert or update of email on auth.users
  for each row execute function public.require_campus_email();
