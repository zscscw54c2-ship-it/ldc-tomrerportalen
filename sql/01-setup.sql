-- Dugnadsplanen: database-oppsett for Supabase.
-- Lim hele denne filen inn i Supabase > SQL Editor > New query, og trykk Run.
--
-- Dette er et lite, lenke-delt verktøy uten innlogging: hvem som helst med
-- lenken til nettsiden kan lese og skrive her (styrt av policyene under, ikke
-- av hemmelig nøkkel - "anon key" er ment å være offentlig). Ikke legg inn
-- sensitiv informasjon (fødselsnummer, passord e.l.) i navn eller notater.

create extension if not exists pgcrypto;

create table if not exists people (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  "group" text,
  created_at timestamptz not null default now()
);

create table if not exists elements (
  id uuid primary key default gen_random_uuid(),
  section text not null check (section in ('innvendig','utvendig')),
  name text not null,
  start date not null,
  "end" date not null,
  notes text,
  done boolean not null default false,
  assignments jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table people enable row level security;
alter table elements enable row level security;

drop policy if exists "anon full access people" on people;
create policy "anon full access people" on people
  for all using (true) with check (true);

drop policy if exists "anon full access elements" on elements;
create policy "anon full access elements" on elements
  for all using (true) with check (true);

-- Live oppdateringer for alle som har siden åpen samtidig.
alter publication supabase_realtime add table people;
alter publication supabase_realtime add table elements;
