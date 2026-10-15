-- KJØRT 2026-10-15.
-- «Ny»-merket på frivillige forsvinner når noen lagrer personkortet (eller etter tre dager).
-- card_edited_at settes av portalen når personkortet lagres. Ingen eksisterende data endres.
alter table public.people add column if not exists card_edited_at timestamptz;
