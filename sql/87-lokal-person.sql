-- Menighetens «Behov for hjelp»: lokale frivillige med kontaktinfo.
--
-- save_local_person oppretter eller oppdaterer en LOKAL frivillig i et prosjekt, på vegne av den som
-- ringer (menigheten har ellers ikke lov til å skrive i people):
--   * p_person_id tom  → ny person med navn, telefon, menighet og adresse, merket tag = 'Lokal', og
--                         Logi satt til «ordner selv» (lokale ordner losji selv - vises ikke i Logi).
--   * p_person_id satt → retter kontaktinfo på en person som ALLEREDE er merket «Lokal» i prosjektet.
--                         Andre personer kan ikke endres herfra.
-- Tilgang: byggeleder, eller menighetskonto («kontakt») låst til akkurat dette prosjektet.
-- Returnerer personens id (brukes så i fill_behov_day for å sette personen på dagen).
--
-- Ingen eksisterende tabeller, regler eller funksjoner endres. Trygt å kjøre flere ganger.

create or replace function public.save_local_person(
  p_project_id uuid, p_person_id uuid default null, p_name text default null,
  p_phone text default null, p_congregation text default null, p_address text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_proj uuid;
  v_name text := left(nullif(btrim(coalesce(p_name, '')), ''), 60);
  v_person uuid;
begin
  select role, project_id into v_role, v_proj from profiles where id = auth.uid();
  if v_role is null then
    raise exception 'Ikke innlogget.';
  end if;
  if not (v_role = 'byggeleder' or (v_role = 'kontakt' and v_proj = p_project_id)) then
    raise exception 'Ingen tilgang til dette prosjektet.';
  end if;
  if v_name is null then
    raise exception 'Navn mangler.';
  end if;

  if p_person_id is null then
    insert into people (name, project_id, phone, congregation, address, tag)
    values (v_name, p_project_id, left(nullif(btrim(coalesce(p_phone, '')), ''), 30),
            left(nullif(btrim(coalesce(p_congregation, '')), ''), 80), left(nullif(btrim(coalesce(p_address, '')), ''), 160), 'Lokal')
    returning id into v_person;
    insert into logi_info (project_id, person_id, status) values (p_project_id, v_person, 'ordner_selv')
    on conflict (project_id, person_id) do update set status = 'ordner_selv';
  else
    update people set
      name = v_name,
      phone = left(nullif(btrim(coalesce(p_phone, '')), ''), 30),
      congregation = left(nullif(btrim(coalesce(p_congregation, '')), ''), 80),
      address = left(nullif(btrim(coalesce(p_address, '')), ''), 160)
    where id = p_person_id and project_id = p_project_id and lower(btrim(coalesce(tag, ''))) = 'lokal'
    returning id into v_person;
    if v_person is null then
      raise exception 'Kan bare endre personer som er merket «Lokal» i dette prosjektet.';
    end if;
  end if;
  return v_person;
end;
$$;

revoke all on function public.save_local_person(uuid, uuid, text, text, text, text) from public, anon;
grant execute on function public.save_local_person(uuid, uuid, text, text, text, text) to authenticated;
