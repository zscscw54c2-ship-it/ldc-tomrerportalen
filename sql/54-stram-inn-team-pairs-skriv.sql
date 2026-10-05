-- LDC CG1: Retter en utilsiktet rettighetsutvidelse fra 51-delt-menighetstilgang.sql.
-- Den migrasjonen skulle KUN fjerne prosjekt-avgrensningen for "kontakt" (menigheten) sin
-- lesetilgang til team_pairs, men ALTER POLICY på "internal full access team_pairs" fjernet
-- samtidig rollesjekken - som betyr at "kontakt" i praksis fikk full skrive/slette-tilgang
-- til team_pairs for ALLE prosjekter, ikke bare lesetilgang slik kommentaren i 51 beskriver.
-- Denne filen gjenoppretter at kun interne roller (ikke "kontakt") kan skrive til team_pairs,
-- uten å røre kontakt sin (uendrede, ikke-prosjekt-avgrensede) lesetilgang fra "kontakt read team_pairs".
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter policy "internal full access team_pairs" on team_pairs
  using (current_profile_role() <> 'kontakt')
  with check (current_profile_role() <> 'kontakt');
