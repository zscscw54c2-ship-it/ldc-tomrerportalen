-- LDC CG1: Behov-siden – byggeleder legger inn behov for hjelp, menighetskontakten
-- (ny rolle "kontakt") foreslår personer som kan hjelpe.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

-- Ny rolle "kontakt" (menighetskontakt) i tillegg til de 7 fagene + byggeleder
alter table profiles drop constraint if exists profiles_role_check;
alter table profiles add constraint profiles_role_check
  check (role in ('tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','byggeleder','kontakt'));

-- Behov: byggeleder oppretter, menighetskontakten (og byggeleder) foreslår folk
create table if not exists behov (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  fag text check (fag in ('tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon')),
  description text not null,
  start_date date,
  end_date date,
  status text not null default 'apen' check (status in ('apen','dekket')),
  created_at timestamptz not null default now()
);
alter table behov enable row level security;
drop policy if exists "authenticated read behov" on behov;
create policy "authenticated read behov" on behov for select to authenticated using (true);
drop policy if exists "byggeleder insert behov" on behov;
create policy "byggeleder insert behov" on behov for insert to authenticated
  with check (current_profile_role() = 'byggeleder');
drop policy if exists "byggeleder update behov" on behov;
create policy "byggeleder update behov" on behov for update to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
drop policy if exists "byggeleder delete behov" on behov;
create policy "byggeleder delete behov" on behov for delete to authenticated
  using (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table behov; exception when duplicate_object then null; end $$;

-- Personer foreslått som tilgjengelige for et behov
create table if not exists behov_forslag (
  id uuid primary key default gen_random_uuid(),
  behov_id uuid not null references behov(id) on delete cascade,
  person_id uuid not null references people(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(behov_id, person_id)
);
alter table behov_forslag enable row level security;
drop policy if exists "authenticated read behov_forslag" on behov_forslag;
create policy "authenticated read behov_forslag" on behov_forslag for select to authenticated using (true);
drop policy if exists "kontakt or byggeleder insert behov_forslag" on behov_forslag;
create policy "kontakt or byggeleder insert behov_forslag" on behov_forslag for insert to authenticated
  with check (current_profile_role() in ('kontakt','byggeleder'));
drop policy if exists "kontakt or byggeleder delete behov_forslag" on behov_forslag;
create policy "kontakt or byggeleder delete behov_forslag" on behov_forslag for delete to authenticated
  using (current_profile_role() in ('kontakt','byggeleder'));
do $$ begin alter publication supabase_realtime add table behov_forslag; exception when duplicate_object then null; end $$;
