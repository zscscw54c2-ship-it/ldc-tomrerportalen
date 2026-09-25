-- LDC - tømrerportalen: åndelig skjema (info, oversikt, ansvarsliste, privilege week, morgentilbedelse)
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table projects add column if not exists spiritual_info text;

create table if not exists spiritual_duties (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  text text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
alter table spiritual_duties enable row level security;
drop policy if exists "anon full access spiritual_duties" on spiritual_duties;
create policy "anon full access spiritual_duties" on spiritual_duties for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table spiritual_duties; exception when duplicate_object then null; end $$;

create table if not exists spiritual_overview (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  kind text not null check (kind in ('program','mote')),
  name text not null,
  time_text text,
  ansvarlig text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
alter table spiritual_overview enable row level security;
drop policy if exists "anon full access spiritual_overview" on spiritual_overview;
create policy "anon full access spiritual_overview" on spiritual_overview for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table spiritual_overview; exception when duplicate_object then null; end $$;

create table if not exists privilege_weeks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  responsible text not null,
  label text,
  familiestudie text,
  sikkerhetstale text,
  bibellesning text,
  note text,
  created_at timestamptz not null default now()
);
alter table privilege_weeks enable row level security;
drop policy if exists "anon full access privilege_weeks" on privilege_weeks;
create policy "anon full access privilege_weeks" on privilege_weeks for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table privilege_weeks; exception when duplicate_object then null; end $$;

create table if not exists morning_worship (
  id uuid primary key default gen_random_uuid(),
  privilege_week_id uuid not null references privilege_weeks(id) on delete cascade,
  slot integer not null check (slot between 1 and 6),
  person_id uuid references people(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (privilege_week_id, slot)
);
alter table morning_worship enable row level security;
drop policy if exists "anon full access morning_worship" on morning_worship;
create policy "anon full access morning_worship" on morning_worship for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table morning_worship; exception when duplicate_object then null; end $$;
