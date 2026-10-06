-- LDC CG1: Leveranser - egen tabell for bestilte varer/leverandører med forventet dato,
-- vist på Team-siden med avkrysning for "mottatt". Fylles enten manuelt eller via den nye
-- "Importer tidsplan + leveranser"-importen (ukeblokk-tidsplan-malen).
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists deliveries (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  name text not null,
  expected_date date,
  uncertain boolean not null default false,
  received boolean not null default false,
  received_date date,
  notes text,
  created_at timestamptz not null default now()
);
alter table deliveries enable row level security;
drop policy if exists "anon full access deliveries" on deliveries;
create policy "anon full access deliveries" on deliveries for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table deliveries; exception when duplicate_object then null; end $$;
