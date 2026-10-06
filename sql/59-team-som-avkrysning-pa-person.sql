-- LDC CG1: Team-medlemskap blir en vanlig avkrysning på personen ("Med i teamet") i stedet
-- for en egen rad i team_pairs med sitt eget navn/fag/adresse. Dette gjør at team-medlemmer
-- får all vanlig kontaktinfo (menighet, telefon, adresse) som andre frivillige, og at man kan
-- opprette noen rett inn i teamet på vanlig måte (eller huke av en eksisterende frivillig).
-- team_pairs-tabellen beholdes urørt i databasen (historikk), men appen slutter å bruke den.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table people add column if not exists on_team boolean not null default false;

update people set on_team = true
where id in (select person_id from team_pairs where person_id is not null);
