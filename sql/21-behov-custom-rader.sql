-- LDC CG1: bytt "Andre behov" fra en egen fritekst-liste til å bli egne rader i det
-- samme fag-rutenettet på Behov-siden ("på samme linje som de andre fagene").
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

drop table if exists behov_extra;

alter table behov_slot alter column fag drop not null;
alter table behov_slot drop constraint if exists behov_slot_fag_check;
alter table behov_slot add constraint behov_slot_fag_check
  check (fag is null or fag in ('tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon'));
alter table behov_slot add column if not exists label text;
alter table behov_slot drop constraint if exists behov_slot_fag_or_label;
alter table behov_slot add constraint behov_slot_fag_or_label check (fag is not null or label is not null);
