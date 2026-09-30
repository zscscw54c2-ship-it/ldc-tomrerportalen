-- LDC CG1: "Ukens skriftsted" og "Teammøte"-agenda (CGO fyller ut, vises på Team-siden).
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists weekly_scriptures (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  week_start date not null,
  text text not null,
  created_at timestamptz not null default now(),
  unique(project_id, week_start)
);
alter table weekly_scriptures enable row level security;
drop policy if exists "anon full access weekly_scriptures" on weekly_scriptures;
create policy "anon full access weekly_scriptures" on weekly_scriptures for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table weekly_scriptures; exception when duplicate_object then null; end $$;

create table if not exists team_meetings (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  week_start date not null,
  agenda text not null default '',
  sent boolean not null default false,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  unique(project_id, week_start)
);
alter table team_meetings enable row level security;
drop policy if exists "anon full access team_meetings" on team_meetings;
create policy "anon full access team_meetings" on team_meetings for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table team_meetings; exception when duplicate_object then null; end $$;
