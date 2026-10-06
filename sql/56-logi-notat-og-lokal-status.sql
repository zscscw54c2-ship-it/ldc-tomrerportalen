-- LDC CG1: To utvidelser til Logi:
-- 1) "Lokal" lagt til som en fjerde logi-status, for frivillige som bor i nærheten og derfor
--    ikke trenger noen logi i det hele tatt (forskjellig fra "Fikser logi selv", som fortsatt
--    betyr at de trenger logi, bare at de ordner den selv).
-- 2) logi_groups.note - fritekstfelt for byggeleder til å notere ting som er relevant for
--    gruppen men ikke passer andre steder, f.eks. at et par har barn med på reisen.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table logi_info drop constraint if exists logi_info_status_check;
alter table logi_info add constraint logi_info_status_check check (status in ('trenger_logi','logi_klart','ordner_selv','lokal'));

alter table logi_groups add column if not exists note text;
