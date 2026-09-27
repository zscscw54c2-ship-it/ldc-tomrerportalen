-- LDC CG1: database for ACGO-siden – fag-aktivering/datoer per prosjekt, og brukerliste.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

-- Hvilke fag som er aktive i et gitt prosjekt, med start-/sluttdato per fag. Kun byggeleder redigerer.
create table if not exists project_fags (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  fag text not null check (fag in ('tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon')),
  active boolean not null default false,
  start_date date,
  end_date date,
  created_at timestamptz not null default now(),
  unique(project_id, fag)
);
alter table project_fags enable row level security;
drop policy if exists "authenticated read project_fags" on project_fags;
create policy "authenticated read project_fags" on project_fags for select to authenticated using (true);
drop policy if exists "byggeleder insert project_fags" on project_fags;
create policy "byggeleder insert project_fags" on project_fags for insert to authenticated
  with check (current_profile_role() = 'byggeleder');
drop policy if exists "byggeleder update project_fags" on project_fags;
create policy "byggeleder update project_fags" on project_fags for update to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
drop policy if exists "byggeleder delete project_fags" on project_fags;
create policy "byggeleder delete project_fags" on project_fags for delete to authenticated
  using (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table project_fags; exception when duplicate_object then null; end $$;

-- Read-only liste over innloggingskontoer (e-post + rolle) for ACGO-siden.
-- auth.users er ikke eksponert via API som standard, så vi lager en filtrert view
-- som kun returnerer rader når spørrende bruker selv er byggeleder.
create or replace view public.user_accounts as
select u.id, u.email, p.role
from auth.users u
join profiles p on p.id = u.id
where current_profile_role() = 'byggeleder';

grant select on public.user_accounts to authenticated;
