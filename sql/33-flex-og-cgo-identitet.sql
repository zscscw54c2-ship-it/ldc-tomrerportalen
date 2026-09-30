-- LDC CG1: FLEX-forespørsler (halv fridag i uken for team) + kobler innloggingskontoer
-- til sin egen person/identitet (Ridderberg=ACGO, Sakkestad=CGO, Bakken=tømrer, Halland=elektriker),
-- slik at "kun team" kan registrere flex og ACGO/CGO vises med riktig navn.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.
-- MERK: UPDATE-linjene nederst bruker faktiske UUID-er fra dette prosjektet. Hvis du kjører dette
-- på et annet Supabase-prosjekt, bytt dem ut med riktige id-er fra auth.users/people/team_pairs.

alter table profiles add column if not exists person_id uuid references people(id) on delete set null;

create table if not exists flex_requests (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  person_id uuid references people(id) on delete cascade,
  week_start date not null,
  day date not null,
  period text not null check (period in ('formiddag','ettermiddag')),
  status text not null default 'pending',
  requested_by text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
alter table flex_requests enable row level security;
drop policy if exists "anon full access flex_requests" on flex_requests;
create policy "anon full access flex_requests" on flex_requests for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table flex_requests; exception when duplicate_object then null; end $$;

update profiles set person_id = '46f0b609-44bd-4884-93ad-ff2affd58789' where id = 'ad1974db-a4a9-4a9c-bbf2-13e9bdf29830'; -- acgo@cg1.org -> Ridderberg
update profiles set person_id = '46f0b609-44bd-4884-93ad-ff2affd58789' where id = '3b37ddda-d1c5-4215-8cd1-0b08b06b4d98'; -- kontor2@cg1.org -> Ridderberg
update profiles set person_id = 'a3b09af4-65d7-40c7-ad14-d44d2811445e' where id = '31040df3-0a0e-4aca-a146-60d3e7044f08'; -- cgo@cg1.org -> Sakkestad
update profiles set person_id = 'a3b09af4-65d7-40c7-ad14-d44d2811445e' where id = '7bb3cce7-00de-458d-8caf-a445eb7d80a3'; -- kontor1@cg1.org -> Sakkestad
update profiles set person_id = '55ea4ca7-7935-419f-a84c-37dc1037f754' where id = '0071a79d-aa8d-4573-ba8c-947dfcc96cdd'; -- tomrer@cg1.org -> Bakken
update profiles set person_id = '3cfff6b2-ecd2-496b-8c1b-172820cb2f2c' where id = '9a7f980d-f213-471d-ad19-b3b19f5f07ff'; -- elektrikker@cg1.org -> Halland
