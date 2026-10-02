-- LDC CG1: manuell rekkefølge på frivillige innen et fag (satt via dra-og-slipp i
-- "Frivillige etter fag"), og grunnlag for å dra en person over til et annet fag.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists people_fag_order (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  fag text not null,
  person_id uuid not null references people(id) on delete cascade,
  sort_order integer not null default 0,
  updated_at timestamptz not null default now(),
  unique(project_id, fag, person_id)
);
alter table people_fag_order enable row level security;
drop policy if exists "authenticated read people_fag_order" on people_fag_order;
create policy "authenticated read people_fag_order" on people_fag_order for select to authenticated using (true);
drop policy if exists "byggeleder write people_fag_order" on people_fag_order;
create policy "byggeleder write people_fag_order" on people_fag_order for all to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table people_fag_order; exception when duplicate_object then null; end $$;
