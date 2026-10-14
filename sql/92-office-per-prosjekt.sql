-- Office per prosjekt (erstatter «felles på tvers av prosjekter» fra sql/91):
--  - office_todos får project_id (slettes sammen med prosjektet); ingen uker lenger.
--  - office_notes: ett notat per prosjekt.
--  - «Saker til møtet» (office_topics) og ukenotater (office_week_notes) brukes ikke lenger
--    (begge er tomme), se nederst.
-- Det ene punktet som finnes («kkk») flyttes til Bø.

alter table public.office_todos add column if not exists project_id uuid references public.projects(id) on delete cascade;
update public.office_todos set project_id = 'ae5a0e64-674a-43d3-b3fe-99f260936496' where project_id is null;
alter table public.office_todos alter column project_id set not null;
alter table public.office_todos alter column created_week drop not null;
create index if not exists office_todos_project on public.office_todos(project_id);

create table if not exists public.office_notes (
  project_id uuid primary key references public.projects(id) on delete cascade,
  body text check (char_length(body) <= 8000),
  updated_at timestamptz not null default now()
);
alter table public.office_notes enable row level security;
create policy "office cg1" on public.office_notes for all to authenticated
  using (public.current_profile_role() = 'byggeleder') with check (public.current_profile_role() = 'byggeleder');
revoke all on public.office_notes from anon;
grant select, insert, update, delete on public.office_notes to authenticated;
alter publication supabase_realtime add table public.office_notes;

-- NB: DROP hang i verktøyet (låst av sanntid). Tabellene er tatt ut av sanntid, er tomme og brukes
-- ikke lenger. Kan slettes i Supabase SQL Editor når det passer:
--   drop table if exists public.office_topics;
--   drop table if exists public.office_week_notes;
alter publication supabase_realtime drop table public.office_topics, public.office_week_notes;

-- Angre (delvis): drop table public.office_notes; alter table public.office_todos drop column project_id;
