-- LDC CG1: Sikkerhetstale flyttes til å vises/tildeles sammen med morgentilbedelsen (over
-- "1. Tekst: Bibelvers"), som en egen slot (0) i morning_worship - med samme person-velger
-- som de andre radene. Selve koden (f.eks "B3") settes fortsatt på privilege-uken
-- (privilege_weeks.sikkerhetstale), kun personen som skal holde den flyttes hit.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table morning_worship drop constraint if exists morning_worship_slot_check;
alter table morning_worship add constraint morning_worship_slot_check check (slot between 0 and 6);
