-- LDC CG1: Legg til "ovrig" (Øvrig) som et eget fag, slik at ACGO kan tagge diverse/forefallende
-- arbeid og handleliste-varer (f.eks. søppelsekker) med sitt eget fag i stedet for å måtte
-- bruke en annen fane eller legge det som en generell TO-møte-sak.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run.

alter table elements drop constraint elements_fag_check;
alter table elements add constraint elements_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','stillas','audio_video','behov_menighet','ovrig']));

alter table shopping_items drop constraint shopping_items_fag_check;
alter table shopping_items add constraint shopping_items_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','ovrig']));

alter table drawings drop constraint drawings_fag_check;
alter table drawings add constraint drawings_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','ovrig']));

alter table attendance drop constraint attendance_fag_check;
alter table attendance add constraint attendance_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','stillas','audio_video','behov_menighet','team','ovrig']));

alter table documentation_photos drop constraint documentation_photos_fag_check;
alter table documentation_photos add constraint documentation_photos_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','ovrig']));

alter table andelig_visibility drop constraint andelig_visibility_fag_check;
alter table andelig_visibility add constraint andelig_visibility_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','ovrig']));

alter table project_fags drop constraint project_fags_fag_check;
alter table project_fags add constraint project_fags_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','ovrig']));

alter table behov_slot drop constraint behov_slot_fag_check;
alter table behov_slot add constraint behov_slot_fag_check
  check (fag is null or fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','ovrig']));

alter table to_meeting_fag_status drop constraint to_meeting_fag_status_fag_check;
alter table to_meeting_fag_status add constraint to_meeting_fag_status_fag_check
  check (fag = any (array['tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','ovrig']));
