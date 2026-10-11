-- Team og Flex på ett sted: hvilken person i teamet hver innlogging hører til, PER PROSJEKT.
--
-- Erstatter (i appen) tre spredte innstillinger: personkoblingen under «Brukere og tilganger»
-- (profiles.person_id – én person for alle prosjekter), «Flex for» og «Vis Team-siden» per fag.
-- Regel i appen: den som er koblet til en person i teamet, ser Team-siden og har Flex.
--
--   account_id – innloggingen: en CG1-bruker (CGO/ACGO/Kontor) eller en fag-kode-konto
--   person_id  – personen i teamet (i samme prosjekt)
-- Én innlogging hører til én person per prosjekt (unik project_id + account_id). Samme person kan
-- ha flere innlogginger (f.eks. en par-rad «Sakkestad» som både CGO og Kontor 1 bruker).
--
-- Alle innloggede kan lese radene for prosjekter de har tilgang til (som P4); bare byggeleder kan
-- endre. Radene forsvinner automatisk når prosjektet, personen eller innloggingen slettes.
-- Trygt å kjøre flere ganger. (Ingenting eksisterende endres.)

create table if not exists public.team_logins (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete cascade,
  account_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (project_id, account_id)
);
alter table public.team_logins enable row level security;

create policy "read team_logins" on public.team_logins for select to authenticated
  using (public.can_see_project(project_id));

create policy "byggeleder write team_logins" on public.team_logins for all to authenticated
  using (public.current_profile_role() = 'byggeleder')
  with check (public.current_profile_role() = 'byggeleder');
revoke all on public.team_logins from anon;
grant select, insert, update, delete on public.team_logins to authenticated;
-- Sanntid (som de andre tabellene). Feiler hvis den allerede er lagt til - det er greit.
alter publication supabase_realtime add table public.team_logins;
