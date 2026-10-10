-- Fase 4, runde 2: innlogging låses til KODE OG PROSJEKT, ikke bare fag. Flyten blir: velg
-- prosjekt → velg fag (bare de som er aktive i det prosjektet) eller "Menighet" → skriv kode.
-- Det betyr at samme fag kan ha forskjellig kode i to prosjekter som går samtidig.
--
-- fag_accounts fra forrige runde hadde ingen rader ennå (CORS-bugen stoppet "Sett kode" før noen
-- fikk brukt den), så tabellen bygges om i stedet for å migreres - nøkkelen er nå
-- (project_id, fag_key) i stedet for bare fag_key. "kontakt" (Menighet) er et gyldig fag_key her
-- selv om det ikke er en rad i "fags" - det er allerede en av de faste, strukturelle verdiene
-- profiles.role godtar (se check_profile_role() i sql/72), så fremmednøkkelen til fags(key)
-- fjernes.
--
-- Menighetens gamle, delte innlogging (sql/51, verify_project_code) RØRES IKKE - den fortsetter å
-- virke akkurat som før. Dette er et nytt, parallelt alternativ, akkurat som avtalt for fagene.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

do $$ begin
  alter table fag_accounts drop constraint fag_accounts_pkey;
exception when undefined_object then null; end $$;
do $$ begin
  alter table fag_accounts drop constraint fag_accounts_fag_key_fkey;
exception when undefined_object then null; end $$;
alter table fag_accounts add column if not exists project_id uuid references projects(id) on delete cascade;
update fag_accounts set project_id = (select id from projects order by name limit 1) where project_id is null;
alter table fag_accounts alter column project_id set not null;
do $$ begin
  alter table fag_accounts add constraint fag_accounts_pkey primary key (project_id, fag_key);
exception when invalid_table_definition then null; end $$;

drop policy if exists "byggeleder read fag_accounts" on fag_accounts;
create policy "byggeleder read fag_accounts" on fag_accounts for select to authenticated
  using (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table fag_accounts; exception when duplicate_object then null; end $$;

-- Lar innloggingssiden vise en prosjektvelger FØR noen er innlogget - bare navn, ingenting
-- sensitivt, samme mønster som list_fags_public (sql/75).
create or replace function list_projects_public()
returns table (id uuid, name text)
language sql
stable security definer
set search_path = public
as $$
  select id, name from projects order by name
$$;
grant execute on function list_projects_public() to anon, authenticated;

-- Når et prosjekt er valgt: hvilke fag (+ evt. "Menighet") kan man logge inn som for DETTE
-- prosjektet. Bare fag som faktisk er aktive i prosjektet vises - "Menighet" er alltid med
-- (lagt til av klienten, ikke her, siden det ikke er en rad i fags).
create or replace function list_project_login_roles(p_project_id uuid)
returns table (key text, label text, color text)
language sql
stable security definer
set search_path = public
as $$
  select f.key, f.label, f.color
  from project_fags pf
  join fags f on f.key = pf.fag
  where pf.project_id = p_project_id and pf.active = true
  order by f.sort_order
$$;
grant execute on function list_project_login_roles(uuid) to anon, authenticated;

-- Oppdatert for det nye, prosjekt-lokaliserte fag_accounts-skjemaet: en delt konto telles som
-- teammedlem når "Vis Team-siden for" er satt for faget I DET PROSJEKTET kontoen er opprettet
-- for (profiles.project_id, satt av Edge Function-en når kontoen opprettes).
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
  or exists (
    select 1 from profiles p
    join fag_accounts fa on fa.auth_user_id = p.id and fa.fag_key = p.role and fa.project_id = p.project_id
    where p.id = auth.uid()
      and p.person_id is null
      and coalesce((select av.visible from andelig_visibility av where av.fag = p.role and av.project_id = p.project_id limit 1), true) = true
  )
$$;
