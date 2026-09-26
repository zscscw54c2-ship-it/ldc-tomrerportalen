-- LDC - tømrerportalen: steg 2 av innloggings-utrullingen.
-- BYTTER om databasetilgangen fra "åpen lenke" til "kun innlogget, kun eget fag".
--
-- VIKTIG REKKEFØLGE: denne filen skal kjøres FØRST ETTER at den nye appkoden
-- (med innloggingsside) er live på Netlify og verifisert å fungere. Kjøres den
-- for tidlig, slutter den gamle (uinnloggede) appen å virke med én gang.
--
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

-- Fag-spesifikke tabeller: kun innlogget, kun eget fag (byggeleder ser/redigerer alt)
do $$
declare tbl text;
begin
  foreach tbl in array array['elements','shopping_items','drawings','documentation_photos','attendance'] loop
    execute format('drop policy if exists %I on %I', 'anon full access '||tbl, tbl);
    execute format('drop policy if exists %I on %I', 'fag access '||tbl, tbl);
    execute format(
      'create policy %I on %I for all to authenticated using (fag = current_profile_role() or current_profile_role() = ''byggeleder'') with check (fag = current_profile_role() or current_profile_role() = ''byggeleder'')',
      'fag access '||tbl, tbl
    );
  end loop;
end $$;

-- Felles tabeller: kun innlogget, alle roller har full tilgang (uendret fra i dag, bare bak innlogging)
do $$
declare tbl text;
begin
  foreach tbl in array array['people','room_todos','spiritual_duties','spiritual_overview','privilege_weeks','morning_worship','privilege_week_duty_status','to_agenda_items','tasks'] loop
    execute format('drop policy if exists %I on %I', 'anon full access '||tbl, tbl);
    execute format('drop policy if exists %I on %I', 'authenticated full access '||tbl, tbl);
    execute format('create policy %I on %I for all to authenticated using (true) with check (true)', 'authenticated full access '||tbl, tbl);
  end loop;
end $$;

-- Prosjekt: alle innloggede kan lese/velge, kun byggeleder kan opprette/redigere/slette
drop policy if exists "anon full access projects" on projects;
drop policy if exists "authenticated read projects" on projects;
drop policy if exists "byggeleder insert projects" on projects;
drop policy if exists "byggeleder update projects" on projects;
drop policy if exists "byggeleder delete projects" on projects;
create policy "authenticated read projects" on projects for select to authenticated using (true);
create policy "byggeleder insert projects" on projects for insert to authenticated
  with check (current_profile_role() = 'byggeleder');
create policy "byggeleder update projects" on projects for update to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
create policy "byggeleder delete projects" on projects for delete to authenticated
  using (current_profile_role() = 'byggeleder');
