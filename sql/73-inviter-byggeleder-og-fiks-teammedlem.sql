-- To uavhengige ting:
--
-- 1) Invitasjonslenker (project_invites) kunne tidligere kun brukes til "kontakt"-rollen
--    (menigheten). Åpner nå også for "byggeleder", slik at byggeleder kan invitere en ny
--    byggeleder/kontakt-konto direkte fra Administrasjon-siden i stedet for å måtte opprette
--    kontoen i Supabase-dashbordet.
--
-- 2) current_profile_is_team_member() sjekket mot den gamle "team_pairs"-tabellen, som ikke
--    har blitt oppdatert siden teamet ble bygget om til å bruke people.on_team (se tidligere
--    migrasjon). team_pairs har i dag 4 rader, mens people.on_team har 12 - det betyr at noen
--    teammedlemmer kan ha mistet leseadgang til Logi uten at noen la merke til det. Retter opp
--    til å bruke people.on_team, som er det appen faktisk viser og redigerer i dag.
--
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table project_invites drop constraint if exists project_invites_role_check;
alter table project_invites add constraint project_invites_role_check check (role in ('kontakt','byggeleder'));

create or replace function current_profile_is_team_member()
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select exists (
    select 1 from profiles p
    join people pp on pp.id = p.person_id
    where p.id = auth.uid() and pp.on_team = true
  )
$$;
