-- KJØRT 2026-10-16.
-- Menighetens fane «Lokale frivillige»: losjikoordinatoren bygger listen over lokale frivillige på
-- forhånd (i stedet for skjema/Excel), og får forslag fra listen når dere etterspør folk i
-- «Behov for hjelp».
--  * people.local_skills: «Kan hjelpe med» (fag-nøkler fra prosjektet, og 'annet').
--  * people.local_note:   notat.
--  * save_local_volunteer(): oppretter/endrer en LOKAL frivillig (tag 'Lokal', losji «ordner selv»)
--    med kontaktinfo, «kan hjelpe med», notat og allergi/diett (mat). Allergiene lagres i logi_info
--    som for alle andre, så de kommer med i matlisten når personen settes på en dag. Menigheten kan
--    fortsatt IKKE endre allergier for andre enn sine lokale frivillige (sql/89).
--  * delete_local_volunteer(): sletter en lokal frivillig (også fra dagene/oppmøtet og oppgavene).
-- Tilgang: byggeleder, eller menighetskonto («kontakt») låst til prosjektet. Bare personer merket
-- «Lokal» i prosjektet kan endres/slettes herfra. Ingen eksisterende data endres.

alter table public.people add column if not exists local_skills text[];
alter table public.people add column if not exists local_note text check (char_length(local_note) <= 500);

-- sql/89: allergilåsen for menigheten slipper gjennom når endringen kommer fra save_local_volunteer.
create or replace function public.logi_info_lock_allergies()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  o public.logi_info%rowtype;
begin
  if coalesce(public.current_profile_role(), '') <> 'kontakt' then return new; end if;
  if coalesce(current_setting('app.local_volunteer', true), '') = '1' then return new; end if;
  if tg_op = 'UPDATE' then
    o := old;
  elsif exists (select 1 from public.logi_info where project_id = new.project_id and person_id = new.person_id) then
    return new;
  end if;
  if coalesce(new.allergier, '') <> coalesce(o.allergier, '')
     or coalesce(new.allergi_mat_tekst, '') <> coalesce(o.allergi_mat_tekst, '')
     or coalesce(new.allergi_logi_tekst, '') <> coalesce(o.allergi_logi_tekst, '')
     or coalesce(new.allergi_mat, false) <> coalesce(o.allergi_mat, false)
     or coalesce(new.allergi_logi, false) <> coalesce(o.allergi_logi, false) then
    raise exception 'Allergier kan bare endres av CG1' using errcode = '42501';
  end if;
  return new;
end $$;

create or replace function public.local_volunteer_access(p_project_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and (role = 'byggeleder' or (role = 'kontakt' and project_id = p_project_id)))
$$;
revoke all on function public.local_volunteer_access(uuid) from public, anon;
grant execute on function public.local_volunteer_access(uuid) to authenticated;

create or replace function public.save_local_volunteer(
  p_project_id uuid, p_person_id uuid default null, p_name text default null,
  p_phone text default null, p_congregation text default null, p_address text default null,
  p_skills text[] default null, p_note text default null,
  p_allergy boolean default false, p_allergy_text text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_name text := left(nullif(btrim(coalesce(p_name, '')), ''), 60);
  v_person uuid;
  v_skills text[] := (select array_agg(distinct s) from unnest(coalesce(p_skills, '{}')) s where s ~ '^[a-z0-9_]{1,40}$');
  v_atext text := left(nullif(btrim(coalesce(p_allergy_text, '')), ''), 300);
begin
  if not public.local_volunteer_access(p_project_id) then raise exception 'Ingen tilgang til dette prosjektet.'; end if;
  if v_name is null then raise exception 'Navn mangler.'; end if;
  if p_person_id is null then
    insert into people (name, project_id, phone, congregation, address, tag, local_skills, local_note)
    values (v_name, p_project_id, left(nullif(btrim(coalesce(p_phone, '')), ''), 30),
            left(nullif(btrim(coalesce(p_congregation, '')), ''), 80), left(nullif(btrim(coalesce(p_address, '')), ''), 160),
            'Lokal', v_skills, left(nullif(btrim(coalesce(p_note, '')), ''), 500))
    returning id into v_person;
  else
    update people set
      name = v_name,
      phone = left(nullif(btrim(coalesce(p_phone, '')), ''), 30),
      congregation = left(nullif(btrim(coalesce(p_congregation, '')), ''), 80),
      address = left(nullif(btrim(coalesce(p_address, '')), ''), 160),
      local_skills = v_skills,
      local_note = left(nullif(btrim(coalesce(p_note, '')), ''), 500)
    where id = p_person_id and project_id = p_project_id and lower(btrim(coalesce(tag, ''))) = 'lokal'
    returning id into v_person;
    if v_person is null then raise exception 'Kan bare endre personer som er merket «Lokal» i dette prosjektet.'; end if;
  end if;
  perform set_config('app.local_volunteer', '1', true);
  insert into logi_info (project_id, person_id, status, allergi_mat, allergi_mat_tekst)
  values (p_project_id, v_person, 'ordner_selv', coalesce(p_allergy, false) or v_atext is not null, v_atext)
  on conflict (project_id, person_id) do update set
    allergi_mat = coalesce(p_allergy, false) or v_atext is not null, allergi_mat_tekst = v_atext,
    status = case when logi_info.status is null or logi_info.status = 'uavklart' then 'ordner_selv' else logi_info.status end;
  perform set_config('app.local_volunteer', '', true);
  return v_person;
end $$;
revoke all on function public.save_local_volunteer(uuid, uuid, text, text, text, text, text[], text, boolean, text) from public, anon;
grant execute on function public.save_local_volunteer(uuid, uuid, text, text, text, text, text[], text, boolean, text) to authenticated;

create or replace function public.delete_local_volunteer(p_project_id uuid, p_person_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.local_volunteer_access(p_project_id) then raise exception 'Ingen tilgang til dette prosjektet.'; end if;
  if not exists (select 1 from people where id = p_person_id and project_id = p_project_id and lower(btrim(coalesce(tag, ''))) = 'lokal') then
    raise exception 'Kan bare slette personer som er merket «Lokal» i dette prosjektet.';
  end if;
  -- Fjern personen fra oppgavene (assignments: { "dag": [person-id, ...] }).
  update elements e set assignments = (
    select coalesce(jsonb_object_agg(k, (select coalesce(jsonb_agg(x), '[]'::jsonb) from jsonb_array_elements(v) x where x <> to_jsonb(p_person_id::text))), '{}'::jsonb)
    from jsonb_each(e.assignments) as a(k, v))
  where e.project_id = p_project_id and e.assignments::text like '%' || p_person_id::text || '%';
  -- Oppmøte og logi slettes, behov-dagen tømmes (fremmednøklene).
  delete from people where id = p_person_id;
end $$;
revoke all on function public.delete_local_volunteer(uuid, uuid) from public, anon;
grant execute on function public.delete_local_volunteer(uuid, uuid) to authenticated;
