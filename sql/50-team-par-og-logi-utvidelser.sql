-- LDC CG1: Team-par kan markeres som par (telles som 2 i frivillig-oversikten) eller én person,
-- og Logi-fanen får Allergier, telefon til logiet, og forenklede statuser.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

-- ---------- team_pairs: par (2 personer) vs. én person ----------
alter table team_pairs add column if not exists is_pair boolean not null default false;

-- ---------- logi_info: allergier + telefon til logiet ----------
alter table logi_info add column if not exists allergier text;
alter table logi_info add column if not exists telefon text;

-- "Ikke vurdert" utgår - "Trenger logi" er nå standard (automatisk) status helt til noen
-- aktivt endrer den, så eksisterende "ikke_vurdert"-rader flyttes dit før den gamle verdien
-- fjernes fra sjekken.
update logi_info set status = 'trenger_logi' where status = 'ikke_vurdert';
alter table logi_info alter column status set default 'trenger_logi';
alter table logi_info drop constraint if exists logi_info_status_check;
alter table logi_info add constraint logi_info_status_check check (status in ('trenger_logi','logi_klart','ordner_selv'));
