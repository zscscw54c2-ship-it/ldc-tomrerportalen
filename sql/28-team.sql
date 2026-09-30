-- LDC CG1: "Team"-siden (tidligere Åndelig) - teamroster (par), og byggeplass-info på prosjektet.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table projects add column if not exists site_address text;
alter table projects add column if not exists eating_address text;
alter table projects add column if not exists meeting_address text;

create table if not exists team_pairs (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  name text not null,
  fag text,
  address text,
  codes text,
  created_at timestamptz not null default now()
);
alter table team_pairs enable row level security;
drop policy if exists "anon full access team_pairs" on team_pairs;
create policy "anon full access team_pairs" on team_pairs for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table team_pairs; exception when duplicate_object then null; end $$;
