-- LDC CG1: Logi-kortet redesignes:
-- - "Lokal" fjernes igjen (kort levetid - erstattes av riktigere modellering under).
-- - Ny status "uavklart" blir standard for alle frivillige helt til noen aktivt velger en status -
--   skiller "ingen har sett på dette ennå" fra "trenger logi" (som nå betyr aktivt vurdert).
-- - "Logi klart" er ikke lenger kombinert med "og melding sendt" i selve statusen - det er nå et
--   eget avkrysningsfelt (melding_sendt) som avgjør om kortet vises gult eller grønt.
-- - Allergier får to uavhengige avkrysninger: gjelder det mat, logi, eller begge.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

update logi_info set status = 'uavklart' where status = 'lokal';
alter table logi_info drop constraint if exists logi_info_status_check;
alter table logi_info add constraint logi_info_status_check check (status in ('uavklart','trenger_logi','logi_klart','ordner_selv'));
alter table logi_info alter column status set default 'uavklart';

alter table logi_info add column if not exists melding_sendt boolean not null default false;
alter table logi_info add column if not exists allergi_mat boolean not null default false;
alter table logi_info add column if not exists allergi_logi boolean not null default false;

-- Allergier registrert FØR denne endringen ble kun noensinne brukt av Mat-siden - sett dem til
-- "gjelder mat" så de ikke forsvinner derfra. "Gjelder logi" er en helt ny ting ingen har tatt
-- stilling til ennå, så den starter bevisst usjekket for alt eksisterende.
update logi_info set allergi_mat = true where allergier is not null and btrim(allergier) <> '';
