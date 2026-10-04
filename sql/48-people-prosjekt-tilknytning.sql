-- Personer skal høre til ett bestemt prosjekt, ikke være globale på tvers av alle.
alter table people add column if not exists project_id uuid references projects(id) on delete cascade;
create index if not exists people_project_id_idx on people(project_id);

-- Engangs-tilbakefylling for eksisterende rader (kjørt direkte mot produksjon 2026-10-04):
-- 1) personer med oppmøte i nøyaktig ett prosjekt -> det prosjektet
-- 2) Kalmar-importen (31 personer, samme created_at-tidsstempel) -> Kalmar
-- 3) resten (14 gamle testrader uten menighet/oppmøte, fra 27. sep) -> Bø som fornuftig standard
-- Disse update-setningene er informasjon om hva som faktisk ble kjørt, ikke ment å kjøres på nytt
-- (project_id er allerede satt not null under).
alter table people alter column project_id set not null;
