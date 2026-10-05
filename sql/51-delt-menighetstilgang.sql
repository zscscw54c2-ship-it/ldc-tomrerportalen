-- LDC CG1: Menigheten bruker nå én delt innlogging for alle prosjekter i stedet for en unik
-- invitasjonslenke per prosjekt. Etter innlogging velger de selv prosjekt og taster inn en
-- tilgangskode (satt av byggeleder på prosjektet) for å låse det opp i nettleseren sin - de
-- kan låse opp flere prosjekter over tid og bytte mellom dem.
--
-- Siden alle menigheter nå deler samme innlogging, kan ikke databasen lenger vite hvilket
-- prosjekt en gitt nettleser har åpnet (det er valgt bevisst, se samtalen i appen/committen):
-- prosjektvalget + kodesjekken er en sperre i appen (grensesnittet), ikke en database-grense
-- håndhevet per rad slik "kontakt"-rollen var låst til ett prosjekt før. "kontakt" får derfor
-- samme (ellers uendrede) tilgang til Behov/Logi/Teamet/oppmøte som før, bare uten den gamle
-- per-rad prosjektfiltreringen.
--
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table projects add column if not exists access_code text;

-- Sjekker om koden stemmer for prosjektet, uten å måtte gi "kontakt"-pålogginger direkte
-- leserett til access_code-kolonnen (den touches kun her, via security definer).
create or replace function verify_project_code(p_project_id uuid, p_code text)
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select exists(
    select 1 from projects
    where id = p_project_id
      and access_code is not null
      and btrim(access_code) <> ''
      and access_code = p_code
  )
$$;
grant execute on function verify_project_code(uuid, text) to authenticated;

-- Bruker ALTER POLICY (ikke DROP+CREATE) på de eksisterende policyene under - de beholder
-- navnet sitt, bare selve betingelsen løses opp for "kontakt".

alter policy "authenticated read projects" on projects using (true);

alter policy "internal full access team_pairs" on team_pairs using (true) with check (true);
alter policy "kontakt read team_pairs" on team_pairs using (true);

alter policy "read all attendance" on attendance using (true);

alter policy "authenticated read behov_slot" on behov_slot using (true);

alter policy "authenticated read behov_day" on behov_day using (true);
alter policy "kontakt or byggeleder update behov_day" on behov_day
  using (current_profile_role() = 'byggeleder' or current_profile_role() = 'kontakt')
  with check (current_profile_role() = 'byggeleder' or current_profile_role() = 'kontakt');

alter policy "les logi_info" on logi_info
  using (current_profile_role() = 'byggeleder' or current_profile_is_team_member() or current_profile_role() = 'kontakt');
alter policy "oppdater logi_info" on logi_info
  using (current_profile_role() = 'byggeleder' or current_profile_role() = 'kontakt')
  with check (current_profile_role() = 'byggeleder' or current_profile_role() = 'kontakt');
