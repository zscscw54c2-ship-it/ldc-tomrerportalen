-- LDC CG1: Ukefordeling på dokumentasjonsbilder. Kamerabilder tagges automatisk til
-- nåværende uke; opplastede bilder må velge en uke (begrenset til prosjektets uker).
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table documentation_photos add column if not exists week_start date;
