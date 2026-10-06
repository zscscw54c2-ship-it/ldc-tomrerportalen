-- LDC CG1: Legg til "blikkenslager" (Blikkenslager) som eget fag, på linje med de andre
-- håndverksfagene (tømrer, VVS, maler, elektriker osv.) - både som arbeidsfag på
-- oppgaver/handleliste/tegninger/dokumentasjon/behov, og som innloggingsrolle siden dette
-- er et reelt fag folk logger inn under (i motsetning til samlekategorien "øvrig").
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run.

alter table profiles drop constraint if exists profiles_role_check;
alter table profiles add constraint profiles_role_check
  check (role in ('tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','blikkenslager','byggeleder','kontakt'));

alter table elements drop constraint elements_fag_check;
alter table elements add constraint elements_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','blikkenslager','stillas','audio_video','behov_menighet','ovrig']));

alter table shopping_items drop constraint shopping_items_fag_check;
alter table shopping_items add constraint shopping_items_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','blikkenslager','ovrig']));

alter table drawings drop constraint drawings_fag_check;
alter table drawings add constraint drawings_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','blikkenslager','ovrig']));

alter table attendance drop constraint attendance_fag_check;
alter table attendance add constraint attendance_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','blikkenslager','stillas','audio_video','behov_menighet','team','ovrig']));

alter table documentation_photos drop constraint documentation_photos_fag_check;
alter table documentation_photos add constraint documentation_photos_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','blikkenslager','ovrig']));

alter table andelig_visibility drop constraint andelig_visibility_fag_check;
alter table andelig_visibility add constraint andelig_visibility_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','blikkenslager','ovrig']));

alter table project_fags drop constraint project_fags_fag_check;
alter table project_fags add constraint project_fags_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','blikkenslager','ovrig']));

alter table behov_slot drop constraint behov_slot_fag_check;
alter table behov_slot add constraint behov_slot_fag_check
  check (fag is null or fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','blikkenslager','ovrig']));

alter table to_meeting_fag_status drop constraint to_meeting_fag_status_fag_check;
alter table to_meeting_fag_status add constraint to_meeting_fag_status_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','blikkenslager','ovrig']));
