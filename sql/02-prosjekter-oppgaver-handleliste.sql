-- LDC - tømrerportalen: database-oppdatering for prosjekter, oppgaver og handleliste.
-- Lim hele denne filen inn i Supabase > SQL Editor > New query, og trykk Run.
-- (Kjøres i tillegg til 01-setup.sql som allerede er kjørt.)

create table if not exists projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  start_date date,
  end_date date,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

alter table elements add column if not exists project_id uuid references projects(id) on delete cascade;

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  section text not null check (section in ('innvendig','utvendig')),
  name text not null,
  description text,
  status text not null default 'mangler' check (status in ('mangler','pabegynt','ferdig')),
  created_at timestamptz not null default now()
);

create table if not exists shopping_items (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  name text not null,
  quantity text,
  notes text,
  bought boolean not null default false,
  created_at timestamptz not null default now()
);

alter table projects enable row level security;
alter table tasks enable row level security;
alter table shopping_items enable row level security;

drop policy if exists "anon full access projects" on projects;
create policy "anon full access projects" on projects
  for all using (true) with check (true);

drop policy if exists "anon full access tasks" on tasks;
create policy "anon full access tasks" on tasks
  for all using (true) with check (true);

drop policy if exists "anon full access shopping_items" on shopping_items;
create policy "anon full access shopping_items" on shopping_items
  for all using (true) with check (true);

alter publication supabase_realtime add table projects;
alter publication supabase_realtime add table tasks;
alter publication supabase_realtime add table shopping_items;
