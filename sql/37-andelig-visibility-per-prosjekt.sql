-- LDC CG1: "Vis Team-siden for" var global pr fag på tvers av ALLE prosjekter. Feil når ulike
-- prosjekter kan ha ulike fag som skal se Team-siden. Gjør om til pr-prosjekt innstilling.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run.
-- MERK: UPDATE-linjen bruker is_active for å flytte dagens globale innstillinger til det
-- aktive prosjektet. Andre prosjekter starter uten rader (= "alle fag synlig", appens vanlige
-- standardverdi når ingen rad finnes).

alter table andelig_visibility add column if not exists project_id uuid references projects(id) on delete cascade;

update andelig_visibility set project_id = (select id from projects where is_active = true limit 1)
where project_id is null;

alter table andelig_visibility drop constraint if exists andelig_visibility_pkey;
alter table andelig_visibility add primary key (project_id, fag);
alter table andelig_visibility alter column project_id set not null;
