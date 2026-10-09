-- LDC CG1: Kobling mellom ektefeller i teamet, slik at flex-forespørsler viser etterparets
-- etternavn i stedet for fullt navn til én person. Rent visningsmessig - påvirker ikke
-- logi-gruppering, oppmøte eller andre funksjoner.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table people add column if not exists spouse_person_id uuid references people(id) on delete set null;
