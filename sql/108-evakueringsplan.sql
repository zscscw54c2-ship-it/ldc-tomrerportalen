-- KJØRT 2026-10-17.
-- Evakueringsplan per prosjekt (eget kort på Team-siden, ved siden av Info). Tom = portalen viser en
-- mal i redigeringsfeltet. Kalmars plan ble kopiert fra Info-tavlen (Info er ikke endret).
alter table public.projects add column if not exists evacuation_plan text check (char_length(evacuation_plan) <= 6000);
update public.projects set evacuation_plan = btrim(replace(substring(spiritual_info from position('(Evakueringsplan Kalmar)' in spiritual_info)), '(Evakueringsplan Kalmar)', 'Evakueringsplan Kalmar'), E' \n')
  where name = 'Kalmar' and evacuation_plan is null and position('(Evakueringsplan Kalmar)' in spiritual_info) > 0;
