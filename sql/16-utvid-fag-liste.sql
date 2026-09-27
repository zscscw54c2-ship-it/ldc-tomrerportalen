-- LDC CG1: bytt fagliste fra (tomrer, maler, elektriker, rorlegger) til de 7 reelle
-- byggegruppene: tomrer, vvs, maler, elektriker, landscape, murer, ventilasjon.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.
--
-- MERK: bytt ut UUID-ene under 4) med de faktiske bruker-ID-ene fra
-- Authentication > Users i Supabase-dashbordet, for kontoene dine.

-- 1) andelig_visibility: fjern rorlegger-raden før vi strammer inn check-constraint, legg til nye fag
delete from andelig_visibility where fag = 'rorlegger';
alter table andelig_visibility drop constraint if exists andelig_visibility_fag_check;
alter table andelig_visibility add constraint andelig_visibility_fag_check
  check (fag in ('tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon'));
insert into andelig_visibility (fag) values ('vvs'),('landscape'),('murer'),('ventilasjon')
  on conflict (fag) do nothing;

-- 2) fag-spesifikke tabeller: oppdater check-constraint til ny fagliste
do $$
declare tbl text;
begin
  foreach tbl in array array['elements','shopping_items','drawings','documentation_photos','attendance'] loop
    execute format('alter table %I drop constraint if exists %I', tbl, tbl||'_fag_check');
    execute format('alter table %I add constraint %I check (fag in (''tomrer'',''vvs'',''maler'',''elektriker'',''landscape'',''murer'',''ventilasjon''))', tbl, tbl||'_fag_check');
  end loop;
end $$;

-- 3) profiles: oppdater rolle-constraint til ny fagliste + byggeleder
alter table profiles drop constraint if exists profiles_role_check;
alter table profiles add constraint profiles_role_check
  check (role in ('tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','byggeleder'));

-- 4) koble kontoene til riktig rolle (upsert). Bytt ut UUID-ene med dine egne fra
-- Authentication > Users, og legg til/fjern rader etter hvilke kontoer du faktisk har.
insert into profiles (id, role)
select id, role from (values
  ('638fc347-38bf-4c2c-8a2a-85ac4be1edb4'::uuid, 'byggeleder'),  -- robin.ridderberg@gmail.com
  ('178a889d-700e-4ff1-b3b5-b7ebf6de6da3'::uuid, 'tomrer'),      -- josteinbakken@icloud.com
  ('ad1974db-a4a9-4a9c-bbf2-13e9bdf29830'::uuid, 'byggeleder'),  -- acgo@cg1.org
  ('4aec4c93-4472-4501-8c3e-a1f9861d6894'::uuid, 'maler'),       -- maler@cg1.org
  ('0071a79d-aa8d-4573-ba8c-947dfcc96cdd'::uuid, 'tomrer'),      -- tomrer@cg1.org
  ('9a7f980d-f213-471d-ad19-b3b19f5f07ff'::uuid, 'elektriker'),  -- elektrikker@cg1.org
  ('29a852e1-e6ec-482d-8037-f9b02f8e7a95'::uuid, 'landscape'),   -- landscape@cg1.org
  ('1b42109f-1f8c-4f87-87f2-e39babf1c5e1'::uuid, 'murer'),       -- murer@cg1.org
  ('4efa8898-2651-4aed-9700-afa5ca383a53'::uuid, 'vvs'),         -- vvs@cg1.org
  ('4f674769-5f94-44ea-8e94-4faf07e21548'::uuid, 'ventilasjon')  -- ventilasjon@cg1.org
) as v(id, role)
on conflict (id) do update set role = excluded.role;
