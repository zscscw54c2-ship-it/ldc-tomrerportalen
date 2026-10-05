-- LDC CG1: Menighetens Logi-side viser nå det samme frivillig-rutenettet som den interne
-- siden (kun lesbar tilgjengelighet, redigerbar logi-info), i stedet for en enkel liste.
-- Siden "Trenger logi" nå er den automatiske standarden for ALLE frivillige (også de uten
-- en egen logi_info-rad ennå), må menigheten kunne opprette raden første gang de fyller inn
-- noe for en person - før kunne "kontakt" bare oppdatere en rad byggeleder hadde opprettet.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter policy "byggeleder insert logi_info" on logi_info
  with check (current_profile_role() = 'byggeleder' or current_profile_role() = 'kontakt');
