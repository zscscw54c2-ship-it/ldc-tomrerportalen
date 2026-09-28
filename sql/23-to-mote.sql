-- LDC CG1: TO-møte (ukentlig møte mellom byggeleder og fag-representanter).
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

-- Fast, redigerbar liste over generelle saker (samme mønster som Privilege Week sine ansvarspunkter)
create table if not exists to_topics (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  text text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
alter table to_topics enable row level security;
drop policy if exists "authenticated read to_topics" on to_topics;
create policy "authenticated read to_topics" on to_topics for select to authenticated using (true);
drop policy if exists "byggeleder write to_topics" on to_topics;
create policy "byggeleder write to_topics" on to_topics for all to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table to_topics; exception when duplicate_object then null; end $$;

-- Ett møte per prosjekt per uke
create table if not exists to_meetings (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  week_start date not null,
  meeting_info text,
  created_at timestamptz not null default now(),
  unique(project_id, week_start)
);
alter table to_meetings enable row level security;
drop policy if exists "authenticated read to_meetings" on to_meetings;
create policy "authenticated read to_meetings" on to_meetings for select to authenticated using (true);
drop policy if exists "byggeleder write to_meetings" on to_meetings;
create policy "byggeleder write to_meetings" on to_meetings for all to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table to_meetings; exception when duplicate_object then null; end $$;

-- Deltakere: én rad per rolle (prosjektleder/arbeidsleder/fag) per møte
create table if not exists to_meeting_attendance (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references to_meetings(id) on delete cascade,
  role_key text not null,
  person_name text,
  present boolean not null default false,
  unique(meeting_id, role_key)
);
alter table to_meeting_attendance enable row level security;
drop policy if exists "authenticated read to_meeting_attendance" on to_meeting_attendance;
create policy "authenticated read to_meeting_attendance" on to_meeting_attendance for select to authenticated using (true);
drop policy if exists "byggeleder write to_meeting_attendance" on to_meeting_attendance;
create policy "byggeleder write to_meeting_attendance" on to_meeting_attendance for all to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table to_meeting_attendance; exception when duplicate_object then null; end $$;

-- Notat per generell sak (to_topics) for et gitt møte
create table if not exists to_meeting_topic_notes (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references to_meetings(id) on delete cascade,
  topic_id uuid not null references to_topics(id) on delete cascade,
  note text,
  unique(meeting_id, topic_id)
);
alter table to_meeting_topic_notes enable row level security;
drop policy if exists "authenticated read to_meeting_topic_notes" on to_meeting_topic_notes;
create policy "authenticated read to_meeting_topic_notes" on to_meeting_topic_notes for select to authenticated using (true);
drop policy if exists "byggeleder write to_meeting_topic_notes" on to_meeting_topic_notes;
create policy "byggeleder write to_meeting_topic_notes" on to_meeting_topic_notes for all to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table to_meeting_topic_notes; exception when duplicate_object then null; end $$;

-- Fag-status per møte. section brukes kun for tømrer (innvendig/utvendig), ellers null.
create table if not exists to_meeting_fag_status (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references to_meetings(id) on delete cascade,
  fag text not null check (fag in ('tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon')),
  section text check (section is null or section in ('innvendig','utvendig')),
  note text,
  unique(meeting_id, fag, section)
);
alter table to_meeting_fag_status enable row level security;
drop policy if exists "authenticated read to_meeting_fag_status" on to_meeting_fag_status;
create policy "authenticated read to_meeting_fag_status" on to_meeting_fag_status for select to authenticated using (true);
drop policy if exists "byggeleder write to_meeting_fag_status" on to_meeting_fag_status;
create policy "byggeleder write to_meeting_fag_status" on to_meeting_fag_status for all to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table to_meeting_fag_status; exception when duplicate_object then null; end $$;

-- Sikkerhetslogg, knyttet til prosjektet (og valgfritt til møtet den ble tatt opp i)
create table if not exists to_safety_log (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  meeting_id uuid references to_meetings(id) on delete set null,
  day date not null default current_date,
  text text not null,
  created_at timestamptz not null default now()
);
alter table to_safety_log enable row level security;
drop policy if exists "authenticated read to_safety_log" on to_safety_log;
create policy "authenticated read to_safety_log" on to_safety_log for select to authenticated using (true);
drop policy if exists "byggeleder write to_safety_log" on to_safety_log;
create policy "byggeleder write to_safety_log" on to_safety_log for all to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table to_safety_log; exception when duplicate_object then null; end $$;

-- Følge opp: løpende liste, overlever på tvers av møter til den er avhuket
create table if not exists to_followups (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  meeting_id uuid references to_meetings(id) on delete set null,
  text text not null,
  ansvarlig text,
  frist date,
  done boolean not null default false,
  created_at timestamptz not null default now()
);
alter table to_followups enable row level security;
drop policy if exists "authenticated read to_followups" on to_followups;
create policy "authenticated read to_followups" on to_followups for select to authenticated using (true);
drop policy if exists "byggeleder write to_followups" on to_followups;
create policy "byggeleder write to_followups" on to_followups for all to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table to_followups; exception when duplicate_object then null; end $$;
