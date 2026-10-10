-- LDC CG1: Tavlene på CG1-sidene blir felles for alle prosjekter, og CGO + ACGO får sine egne
-- tavler på samme måte som Kontor 1 og Kontor 2.
--
-- 1) office_boxes.project_id blir valgfri (null = felles tavle for alle prosjekter). Appen lager
--    nå alltid nye tavler med project_id = null, og viser alle tavlene for en side uansett hvilket
--    prosjekt som er valgt - de "starter ikke på nytt" når et nytt prosjekt opprettes.
--    Eksisterende tavler (hvis noen) flyttes over til felles, så ingenting forsvinner fra visningen.
--    Fremmednøkkelen til projects beholdes, men med "on delete set null" i stedet for cascade, så
--    en tavle ikke slettes sammen med et prosjekt.
-- 2) office tillater nå også 'cgo' og 'acgo' i tillegg til 'kontor1' og 'kontor2'.
--
-- Tilgangsreglene (RLS) på office_boxes og under-tabellene endres IKKE.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table office_boxes alter column project_id drop not null;
update office_boxes set project_id = null where project_id is not null;

alter table office_boxes drop constraint if exists office_boxes_project_id_fkey;
alter table office_boxes add constraint office_boxes_project_id_fkey
  foreign key (project_id) references projects(id) on delete set null;

alter table office_boxes drop constraint if exists office_boxes_office_check;
alter table office_boxes add constraint office_boxes_office_check
  check (office in ('cgo','acgo','kontor1','kontor2'));
