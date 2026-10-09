-- LDC CG1: Privilege week-sjekklisten (ansvarspunkter) er allerede prosjekt-scoped og endres
-- ikke uke til uke innad i et prosjekt, men manglet helt i nye prosjekter siden den må skrives
-- inn manuelt. Appen seeder nå samme standardliste automatisk når et nytt prosjekt opprettes
-- (se createProject() i index.html). Denne filen backfiller ETT-GANGS alle eksisterende
-- prosjekter som i dag mangler ansvarspunkter helt, med samme standardliste.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere
-- ganger - rører kun prosjekter som fortsatt har 0 ansvarspunkter.

insert into spiritual_duties (project_id, text, sort_order)
select p.id, t.text, t.ord - 1
from projects p
cross join lateral (
  select * from unnest(array[
    'Live MW (fredag)', 'Åndelig tanke teammøte', 'Avslutte med sang – fredag', 'Lede familiestudie',
    'Lede & skrive risikoanalyse', 'Starte streaming', 'Sikkerhetstale (tirsdag)', 'Napo (torsdag)',
    'Sikkerhetsrunde (torsdag)', 'Inn & ut-sjekkings'
  ]) with ordinality as u(text, ord)
) t
where not exists (select 1 from spiritual_duties d where d.project_id = p.id);
