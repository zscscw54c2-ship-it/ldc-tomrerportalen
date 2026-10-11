-- LDC CG1: Menighetens utfylling av "Behov for hjelp" virket bare halvveis. Navnet ble lagret på
-- dagen, men
--   * oppmøtet ble ikke registrert (attendance tillater bare faget selv eller byggeleder), og
--   * "Eller skriv et nytt navn" feilet helt (menigheten får ikke legge til personer i people).
--
-- fill_behov_day gjør hele utfyllingen i én operasjon, på vegne av den som ringer:
--   1. legger til en ny person i prosjektet (hvis p_new_name er gitt), ellers bruker p_person_id
--      (som må høre til samme prosjekt) - eller tømmer dagen hvis begge er tomme,
--   2. setter personen på behov-dagen,
--   3. registrerer oppmøte (fag = radens fag, eller 'behov_menighet' for "andre behov"),
--   4. for "andre behov": legger personen til på kalender-oppgaven for dagen (oppretter den om den
--      ikke finnes) - samme logikk som appen hadde fra før.
-- Tilgang: byggeleder (alle prosjekter), eller menighetskonto ("kontakt") som er låst til akkurat
-- prosjektet dagen hører til (profiles.project_id). Alle andre avvises.
--
-- Ingen eksisterende tabeller eller tilgangsregler endres.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create or replace function public.fill_behov_day(p_day_id uuid, p_person_id uuid default null, p_new_name text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_proj uuid;
  v_day behov_day%rowtype;
  v_slot behov_slot%rowtype;
  v_person uuid;
  v_name text;
  v_el elements%rowtype;
  v_key text;
  v_ids jsonb;
  v_label text;
begin
  select role, project_id into v_role, v_proj from profiles where id = auth.uid();
  if v_role is null then
    raise exception 'Ikke innlogget.';
  end if;

  select * into v_day from behov_day where id = p_day_id;
  if not found then
    raise exception 'Fant ikke behov-dagen.';
  end if;
  select * into v_slot from behov_slot where id = v_day.slot_id;

  if not (v_role = 'byggeleder' or (v_role = 'kontakt' and v_proj = v_slot.project_id)) then
    raise exception 'Ingen tilgang til dette prosjektet.';
  end if;

  v_name := nullif(btrim(coalesce(p_new_name, '')), '');
  if v_name is not null then
    insert into people (name, project_id) values (left(v_name, 60), v_slot.project_id) returning id into v_person;
  elsif p_person_id is not null then
    select id into v_person from people where id = p_person_id and project_id = v_slot.project_id;
    if v_person is null then
      raise exception 'Personen hører ikke til dette prosjektet.';
    end if;
  else
    v_person := null;
  end if;

  update behov_day set person_id = v_person where id = p_day_id;
  if v_person is null then
    return null;
  end if;

  insert into attendance (project_id, person_id, day, fag)
  values (v_slot.project_id, v_person, v_day.day, coalesce(v_slot.fag, 'behov_menighet'))
  on conflict (project_id, person_id, day) do update set fag = excluded.fag;

  if v_slot.fag is null then
    v_key := to_char(v_day.day, 'YYYY-MM-DD');
    v_label := left(coalesce(nullif(btrim(v_slot.label), ''), 'Behov'), 120);
    select * into v_el from elements
      where project_id = v_slot.project_id and fag = 'behov_menighet'
        and start = v_day.day and "end" = v_day.day and name = v_label
      limit 1;
    if found then
      v_ids := coalesce(v_el.assignments -> v_key, '[]'::jsonb);
      if not (v_ids @> jsonb_build_array(v_person)) then
        update elements set assignments = jsonb_set(coalesce(assignments, '{}'::jsonb), array[v_key], v_ids || jsonb_build_array(v_person), true)
          where id = v_el.id;
      end if;
    else
      insert into elements (project_id, section, name, start, "end", status, fag, assignments, done)
      values (v_slot.project_id, 'utvendig', v_label, v_day.day, v_day.day, 'mangler', 'behov_menighet',
              jsonb_build_object(v_key, jsonb_build_array(v_person)), false);
    end if;
  end if;

  return v_person;
end;
$$;

revoke all on function public.fill_behov_day(uuid, uuid, text) from public, anon;
grant execute on function public.fill_behov_day(uuid, uuid, text) to authenticated;
