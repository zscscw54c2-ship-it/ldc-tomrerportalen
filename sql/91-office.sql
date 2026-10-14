-- Office: felles ukentlig møte for CGO, ACGO, Kontor 1 og Kontor 2.
-- Felles på tvers av prosjekter (ingen project_id), som CG1-tavlene. Alle fire kan endre alt.
-- Tilgang: bare CG1-innlogginger (rolle byggeleder), samme regel som CG1-tavlene (office_boxes).
-- Bare NYE tabeller - ingen eksisterende data endres.
--
-- office_topics:      saker til møtet, per uke (week_start = mandag), med notat fra møtet
-- office_todos:       to-do med ansvarlig rolle og frist; åpne punkter følger med til de er huket av
-- office_week_notes:  fritekst-notat/referat per uke

create table if not exists public.office_topics (
  id uuid primary key default gen_random_uuid(),
  week_start date not null,
  text text not null check (char_length(text) <= 300),
  note text check (char_length(note) <= 2000),
  done boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists office_topics_week on public.office_topics(week_start);

create table if not exists public.office_todos (
  id uuid primary key default gen_random_uuid(),
  text text not null check (char_length(text) <= 300),
  responsible text check (responsible in ('cgo', 'acgo', 'kontor1', 'kontor2')),
  due_date date,
  done boolean not null default false,
  done_at timestamptz,
  created_week date not null,
  created_at timestamptz not null default now()
);

create table if not exists public.office_week_notes (
  week_start date primary key,
  body text check (char_length(body) <= 8000),
  updated_at timestamptz not null default now()
);

alter table public.office_topics enable row level security;
alter table public.office_todos enable row level security;
alter table public.office_week_notes enable row level security;

create policy "office cg1" on public.office_topics for all to authenticated
  using (public.current_profile_role() = 'byggeleder') with check (public.current_profile_role() = 'byggeleder');
create policy "office cg1" on public.office_todos for all to authenticated
  using (public.current_profile_role() = 'byggeleder') with check (public.current_profile_role() = 'byggeleder');
create policy "office cg1" on public.office_week_notes for all to authenticated
  using (public.current_profile_role() = 'byggeleder') with check (public.current_profile_role() = 'byggeleder');

revoke all on public.office_topics, public.office_todos, public.office_week_notes from anon;
grant select, insert, update, delete on public.office_topics, public.office_todos, public.office_week_notes to authenticated;

-- Sanntid (endringer vises live hos alle fire).
alter publication supabase_realtime add table public.office_topics;
alter publication supabase_realtime add table public.office_todos;
alter publication supabase_realtime add table public.office_week_notes;

-- Angre: drop table public.office_topics, public.office_todos, public.office_week_notes;
