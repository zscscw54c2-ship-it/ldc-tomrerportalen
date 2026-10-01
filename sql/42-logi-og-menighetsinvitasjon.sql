-- LDC CG1: Logi-koordinering + selvregistrering for menigheten via unik, prosjekt-avgrenset
-- invitasjonslenke. Utvider den eksisterende "kontakt"-rollen (menighetskontakt) til å dekke
-- Logi i tillegg til Behov, og låser den til ett prosjekt om gangen.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

-- ---------- profiles: prosjekt-avgrensning for kontakt-rollen (må finnes før funksjonen under) ----------
alter table profiles add column if not exists project_id uuid references projects(id) on delete set null;

-- Fantes allerede en "kontakt"-konto (f.eks. kontakt@cg1.org) uten project_id satt, ville den miste
-- all tilgang når policyene under innføres. Kobler den til det aktive prosjektet som en engangsjobb;
-- rører ikke rader som allerede har fått et prosjekt (f.eks. via en invitasjonslenke).
update profiles set project_id = (select id from projects where is_active = true limit 1)
where role = 'kontakt' and project_id is null;

-- ---------- hjelpefunksjoner ----------

-- Hvilket prosjekt en "kontakt"-innlogging er avgrenset til (null for alle andre roller).
create or replace function current_profile_project_id()
returns uuid
language sql
stable security definer
set search_path = public
as $$
  select project_id from profiles where id = auth.uid()
$$;

-- Er den innloggede koblet (via profiles.person_id) til et teammedlem i et prosjekt?
-- Brukes til å avgrense Logi-innsyn til Teamet, ikke alle vanlige fag-innlogginger.
create or replace function current_profile_is_team_member()
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select exists (
    select 1 from profiles p
    join team_pairs tp on tp.person_id = p.person_id
    where p.id = auth.uid() and p.person_id is not null
  )
$$;

-- ---------- invitasjonslenker ----------
create table if not exists project_invites (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  role text not null default 'kontakt' check (role in ('kontakt')),
  token text not null unique default encode(gen_random_bytes(24), 'hex'),
  label text,
  created_at timestamptz not null default now(),
  used_by uuid references auth.users(id),
  used_at timestamptz
);
alter table project_invites enable row level security;
drop policy if exists "byggeleder manage project_invites" on project_invites;
create policy "byggeleder manage project_invites" on project_invites for all to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table project_invites; exception when duplicate_object then null; end $$;

-- Slår opp prosjektnavnet for en invitasjonstoken FØR man har en konto (så registreringssiden kan
-- vise "Du inviteres til prosjektet: X"), uten å eksponere hele project_invites-tabellen til anon.
create or replace function get_invite_project_name(invite_token text)
returns text
language sql
stable security definer
set search_path = public
as $$
  select p.name from project_invites pi
  join projects p on p.id = pi.project_id
  where pi.token = invite_token and pi.used_at is null
$$;
grant execute on function get_invite_project_name(text) to anon, authenticated;

-- Kalles rett etter at menigheten har satt eget passord (auth.signUp). Oppretter/oppdaterer
-- profiles-raden med rollen og prosjektet fra invitasjonen, og merker lenken som brukt.
-- security definer fordi en splitter ny bruker ikke har egen profiles-rad eller skriverettighet ennå.
create or replace function claim_project_invite(invite_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  inv record;
begin
  select * into inv from project_invites where token = invite_token and used_at is null;
  if not found then
    raise exception 'Ugyldig eller allerede brukt invitasjonslenke.';
  end if;

  insert into profiles (id, role, project_id)
  values (auth.uid(), inv.role, inv.project_id)
  on conflict (id) do update set role = excluded.role, project_id = excluded.project_id;

  update project_invites set used_by = auth.uid(), used_at = now() where id = inv.id;
end;
$$;
grant execute on function claim_project_invite(text) to authenticated;

-- ---------- logi_info: status og detaljer per person/prosjekt ----------
create table if not exists logi_info (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  person_id uuid not null references people(id) on delete cascade,
  status text not null default 'ikke_vurdert' check (status in ('ikke_vurdert','trenger_logi','logi_klart','ordner_selv')),
  adresse text,
  koder text,
  kontaktinfo text,
  melding text,
  created_at timestamptz not null default now(),
  unique(project_id, person_id)
);
alter table logi_info enable row level security;
drop policy if exists "les logi_info" on logi_info;
create policy "les logi_info" on logi_info for select to authenticated
  using (
    current_profile_role() = 'byggeleder'
    or (current_profile_role() <> 'kontakt' and current_profile_is_team_member())
    or (current_profile_role() = 'kontakt' and project_id = current_profile_project_id())
  );
drop policy if exists "byggeleder insert logi_info" on logi_info;
create policy "byggeleder insert logi_info" on logi_info for insert to authenticated
  with check (current_profile_role() = 'byggeleder');
drop policy if exists "oppdater logi_info" on logi_info;
create policy "oppdater logi_info" on logi_info for update to authenticated
  using (
    current_profile_role() = 'byggeleder'
    or (current_profile_role() = 'kontakt' and project_id = current_profile_project_id())
  )
  with check (
    current_profile_role() = 'byggeleder'
    or (current_profile_role() = 'kontakt' and project_id = current_profile_project_id())
  );
drop policy if exists "byggeleder delete logi_info" on logi_info;
create policy "byggeleder delete logi_info" on logi_info for delete to authenticated
  using (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table logi_info; exception when duplicate_object then null; end $$;

-- ---------- avgrens kontakt til eget prosjekt på eksisterende tabeller ----------
-- (alle andre roller er uendret – kun kontakt-rollen får prosjektfiltrering lagt på)

drop policy if exists "authenticated read projects" on projects;
create policy "authenticated read projects" on projects for select to authenticated
  using (current_profile_role() <> 'kontakt' or id = current_profile_project_id());

drop policy if exists "authenticated full access team_pairs" on team_pairs;
create policy "internal full access team_pairs" on team_pairs for all to authenticated
  using (current_profile_role() <> 'kontakt') with check (current_profile_role() <> 'kontakt');
drop policy if exists "kontakt read team_pairs" on team_pairs;
create policy "kontakt read team_pairs" on team_pairs for select to authenticated
  using (current_profile_role() = 'kontakt' and project_id = current_profile_project_id());

drop policy if exists "read all attendance" on attendance;
create policy "read all attendance" on attendance for select to authenticated
  using (current_profile_role() <> 'kontakt' or project_id = current_profile_project_id());

drop policy if exists "authenticated read behov_slot" on behov_slot;
create policy "authenticated read behov_slot" on behov_slot for select to authenticated
  using (current_profile_role() <> 'kontakt' or project_id = current_profile_project_id());

drop policy if exists "authenticated read behov_day" on behov_day;
create policy "authenticated read behov_day" on behov_day for select to authenticated
  using (
    current_profile_role() <> 'kontakt'
    or exists (select 1 from behov_slot s where s.id = behov_day.slot_id and s.project_id = current_profile_project_id())
  );
drop policy if exists "kontakt or byggeleder update behov_day" on behov_day;
create policy "kontakt or byggeleder update behov_day" on behov_day for update to authenticated
  using (
    current_profile_role() = 'byggeleder'
    or (current_profile_role() = 'kontakt' and exists (select 1 from behov_slot s where s.id = behov_day.slot_id and s.project_id = current_profile_project_id()))
  )
  with check (
    current_profile_role() = 'byggeleder'
    or (current_profile_role() = 'kontakt' and exists (select 1 from behov_slot s where s.id = behov_day.slot_id and s.project_id = current_profile_project_id()))
  );

-- people: navn er lav sensitivitet og leses i dag av alle (bl.a. for Behov-forslag), men kun
-- interne roller skal kunne opprette/redigere/slette personer.
drop policy if exists "authenticated full access people" on people;
create policy "authenticated read people" on people for select to authenticated using (true);
create policy "internal write people" on people for insert to authenticated with check (current_profile_role() <> 'kontakt');
create policy "internal update people" on people for update to authenticated using (current_profile_role() <> 'kontakt') with check (current_profile_role() <> 'kontakt');
create policy "internal delete people" on people for delete to authenticated using (current_profile_role() <> 'kontakt');
