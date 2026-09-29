-- LDC CG1: mulighet for å avslutte et TO-møte og publisere referatet til fag.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table to_meetings add column if not exists concluded boolean not null default false;
