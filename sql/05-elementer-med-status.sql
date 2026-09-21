-- LDC - tømrerportalen: slå sammen oppgaver og elementer.
-- Elementer får status (mangler / påbegynt / ferdig) og kan finnes uten datoer
-- (= ikke lagt inn i fremdriftsplanen ennå).
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table elements add column if not exists status text not null default 'mangler';
alter table elements drop constraint if exists elements_status_check;
alter table elements add constraint elements_status_check check (status in ('mangler','pabegynt','ferdig'));
update elements set status = 'ferdig' where done = true and status <> 'ferdig';

alter table elements alter column start drop not null;
alter table elements alter column "end" drop not null;

-- Flytt eksisterende oppgaver inn som elementer (uten datoer). Oppgavetabellen beholdes urørt.
insert into elements (project_id, section, name, notes, status, done)
select t.project_id, t.section, t.name, t.description, t.status, t.status = 'ferdig'
from tasks t
where not exists (
  select 1 from elements e
  where e.name = t.name and e.section = t.section and e.project_id is not distinct from t.project_id
);
