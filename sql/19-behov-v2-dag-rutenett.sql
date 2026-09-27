-- LDC CG1: bytter ut den enkle Behov-listen (sql/18) med en dag-for-dag-rutenett-modell.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.
-- MERK: dette sletter de gamle tabellene behov/behov_forslag fra sql/18. Kjør kun denne
-- filen hvis du ikke har viktige data i dem ennå (de var tomme da denne ble skrevet).

drop view if exists public.behov_forslag_view;
drop table if exists behov_forslag;
drop table if exists behov;

-- En "plass" (ønsket person) for et fag i et prosjekt. Byggeleder styrer antallet
-- ved å opprette/slette rader (slot_index 1, 2, 3 ...).
create table behov_slot (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  fag text not null check (fag in ('tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon')),
  slot_index integer not null,
  created_at timestamptz not null default now(),
  unique(project_id, fag, slot_index)
);
alter table behov_slot enable row level security;
drop policy if exists "authenticated read behov_slot" on behov_slot;
create policy "authenticated read behov_slot" on behov_slot for select to authenticated using (true);
drop policy if exists "byggeleder insert behov_slot" on behov_slot;
create policy "byggeleder insert behov_slot" on behov_slot for insert to authenticated
  with check (current_profile_role() = 'byggeleder');
drop policy if exists "byggeleder delete behov_slot" on behov_slot;
create policy "byggeleder delete behov_slot" on behov_slot for delete to authenticated
  using (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table behov_slot; exception when duplicate_object then null; end $$;

-- En markert dag for en plass. person_id null = trengs, men ikke fylt inn ennå.
create table behov_day (
  id uuid primary key default gen_random_uuid(),
  slot_id uuid not null references behov_slot(id) on delete cascade,
  day date not null,
  person_id uuid references people(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(slot_id, day)
);
alter table behov_day enable row level security;
drop policy if exists "authenticated read behov_day" on behov_day;
create policy "authenticated read behov_day" on behov_day for select to authenticated using (true);
drop policy if exists "byggeleder insert behov_day" on behov_day;
create policy "byggeleder insert behov_day" on behov_day for insert to authenticated
  with check (current_profile_role() = 'byggeleder');
drop policy if exists "byggeleder delete behov_day" on behov_day;
create policy "byggeleder delete behov_day" on behov_day for delete to authenticated
  using (current_profile_role() = 'byggeleder');
drop policy if exists "kontakt or byggeleder update behov_day" on behov_day;
create policy "kontakt or byggeleder update behov_day" on behov_day for update to authenticated
  using (current_profile_role() in ('kontakt','byggeleder')) with check (current_profile_role() in ('kontakt','byggeleder'));
do $$ begin alter publication supabase_realtime add table behov_day; exception when duplicate_object then null; end $$;
