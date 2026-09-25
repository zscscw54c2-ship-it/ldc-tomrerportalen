-- LDC - tømrerportalen: TO-møte-saker, rom-todo-lister, og avhuking av privilege week-ansvar.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists to_agenda_items (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now()
);
alter table to_agenda_items enable row level security;
drop policy if exists "anon full access to_agenda_items" on to_agenda_items;
create policy "anon full access to_agenda_items" on to_agenda_items for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table to_agenda_items; exception when duplicate_object then null; end $$;

create table if not exists room_todos (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  room text not null,
  text text not null,
  done boolean not null default false,
  created_at timestamptz not null default now()
);
alter table room_todos enable row level security;
drop policy if exists "anon full access room_todos" on room_todos;
create policy "anon full access room_todos" on room_todos for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table room_todos; exception when duplicate_object then null; end $$;

create table if not exists privilege_week_duty_status (
  id uuid primary key default gen_random_uuid(),
  privilege_week_id uuid not null references privilege_weeks(id) on delete cascade,
  duty_id uuid not null references spiritual_duties(id) on delete cascade,
  done boolean not null default false,
  delegated_person_id uuid references people(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (privilege_week_id, duty_id)
);
alter table privilege_week_duty_status enable row level security;
drop policy if exists "anon full access privilege_week_duty_status" on privilege_week_duty_status;
create policy "anon full access privilege_week_duty_status" on privilege_week_duty_status for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table privilege_week_duty_status; exception when duplicate_object then null; end $$;
