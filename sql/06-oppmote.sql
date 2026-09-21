-- LDC - tømrerportalen: oppmøte - hvilke dager hver person er med i et prosjekt.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists attendance (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  person_id uuid not null references people(id) on delete cascade,
  day date not null,
  created_at timestamptz not null default now(),
  unique (project_id, person_id, day)
);

alter table attendance enable row level security;

drop policy if exists "anon full access attendance" on attendance;
create policy "anon full access attendance" on attendance
  for all using (true) with check (true);

do $$ begin
  alter publication supabase_realtime add table attendance;
exception when duplicate_object then null; end $$;
