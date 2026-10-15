-- KJØRT 2026-10-15.
-- Fritekst-info på personkortet (f.eks. «Singel søster») for losji-koordinatoren.
-- Bare informasjon på kortet - ikke en tagg og ingen gruppe. Ingen eksisterende data endres.
alter table public.people add column if not exists info text check (char_length(info) <= 200);
