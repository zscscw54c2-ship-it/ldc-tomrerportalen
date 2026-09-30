-- LDC CG1: La alle innloggede kunne LESE oppgaver ("elements") på tvers av fag,
-- slik at "Ukas mål" på Team-siden viser alle fags mål og ikke bare sitt eget.
-- Skriving (opprette/endre/slette) er fortsatt begrenset til eget fag (eller byggeleder).
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

drop policy if exists "fag access elements" on elements;

create policy "read all elements" on elements
  for select using (true);

create policy "fag insert elements" on elements
  for insert with check (fag = current_profile_role() or current_profile_role() = 'byggeleder');

create policy "fag update elements" on elements
  for update using (fag = current_profile_role() or current_profile_role() = 'byggeleder')
  with check (fag = current_profile_role() or current_profile_role() = 'byggeleder');

create policy "fag delete elements" on elements
  for delete using (fag = current_profile_role() or current_profile_role() = 'byggeleder');
