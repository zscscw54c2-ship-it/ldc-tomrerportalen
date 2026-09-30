-- LDC CG1: Samme mønster som ble rettet for "elements" (Ukas mål): attendance-tabellen hadde
-- en kombinert les+skriv-policy begrenset til eget fag (eller byggeleder). Det gjorde at
-- vanlige fag-innlogginger aldri kunne se "team"-fagets oppmøte, selv om flere funksjoner
-- (bl.a. Teamet-kortets "dager tilgjengelig"-teller på Team-siden) er ment å vise dette på
-- tvers av fag. Åpner LESING for alle innloggede, holder SKRIVING begrenset til eget fag.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

drop policy if exists "fag access attendance" on attendance;

create policy "read all attendance" on attendance
  for select to authenticated using (true);

create policy "fag insert attendance" on attendance
  for insert to authenticated with check (fag = current_profile_role() or current_profile_role() = 'byggeleder');

create policy "fag update attendance" on attendance
  for update to authenticated using (fag = current_profile_role() or current_profile_role() = 'byggeleder')
  with check (fag = current_profile_role() or current_profile_role() = 'byggeleder');

create policy "fag delete attendance" on attendance
  for delete to authenticated using (fag = current_profile_role() or current_profile_role() = 'byggeleder');
