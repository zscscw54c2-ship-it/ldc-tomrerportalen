-- LDC CG1: gjør "Behov fra menigheten" til et virtuelt fag i oversikts-rutenettet og
-- kalenderen, slik at personer som fyller inn et behov utenfor de faste fagene
-- vises under "Behov fra menigheten" i "Frivillige etter fag", og får en
-- automatisk oppgave i kalenderen på riktig dato.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table attendance drop constraint if exists attendance_fag_check;
alter table attendance add constraint attendance_fag_check
  check (fag in ('tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','stillas','audio_video','behov_menighet'));

alter table elements drop constraint if exists elements_fag_check;
alter table elements add constraint elements_fag_check
  check (fag in ('tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','stillas','audio_video','behov_menighet'));
