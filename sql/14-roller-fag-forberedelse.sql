-- LDC - tømrerportalen: forberedelse for innlogging per fag (tømrer/maler/elektriker/rørlegger + byggeleder).
-- Dette er STEG 1-2 av flere: nye tabeller/kolonner, IKKE en innstramming av dagens tilgang ennå.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.
--
-- MERK: Dagens "anon full access"-policyer på alle tabeller står fortsatt urørt i denne filen.
-- Den faktiske innstrammingen til "kun innlogget, kun eget fag" kommer i en egen migrasjon
-- SAMTIDIG som innloggingssiden og fag-bevisst appkode rulles ut, slik at siden aldri
-- slutter å virke midt i utrullingen.

-- Profiler / roller (én rad per konto: tomrer, maler, elektriker, rorlegger, byggeleder)
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('tomrer','maler','elektriker','rorlegger','byggeleder')),
  created_at timestamptz not null default now()
);
alter table profiles enable row level security;

-- Hjelpefunksjon: rollen til den innloggede brukeren. security definer for å unngå
-- rekursjon i RLS-policyer som selv sjekker rollen.
create or replace function current_profile_role()
returns text
language sql
security definer
set search_path = public
stable
as $$
  select role from profiles where id = auth.uid()
$$;

drop policy if exists "read own or byggeleder profile" on profiles;
create policy "read own or byggeleder profile" on profiles for select to authenticated
  using (id = auth.uid() or current_profile_role() = 'byggeleder');

-- fag-kolonne på de fag-spesifikke tabellene. Alt eksisterende data merkes 'tomrer'
-- siden verktøyet fram til nå kun har vært brukt av tømrer-gruppa.
do $$
declare tbl text;
begin
  foreach tbl in array array['elements','shopping_items','drawings','documentation_photos','attendance'] loop
    execute format('alter table %I add column if not exists fag text', tbl);
    execute format('update %I set fag = ''tomrer'' where fag is null', tbl);
    execute format('alter table %I alter column fag set default ''tomrer''', tbl);
    execute format('alter table %I alter column fag set not null', tbl);
    execute format('alter table %I drop constraint if exists %I', tbl, tbl||'_fag_check');
    execute format('alter table %I add constraint %I check (fag in (''tomrer'',''maler'',''elektriker'',''rorlegger''))', tbl, tbl||'_fag_check');
  end loop;
end $$;

-- Byggeleder kan skru Åndelig-siden av/på per byggegruppe
create table if not exists andelig_visibility (
  fag text primary key check (fag in ('tomrer','maler','elektriker','rorlegger')),
  visible boolean not null default true
);
insert into andelig_visibility (fag) values ('tomrer'),('maler'),('elektriker'),('rorlegger')
  on conflict (fag) do nothing;
alter table andelig_visibility enable row level security;
drop policy if exists "authenticated read andelig_visibility" on andelig_visibility;
create policy "authenticated read andelig_visibility" on andelig_visibility for select to authenticated using (true);
drop policy if exists "byggeleder update andelig_visibility" on andelig_visibility;
create policy "byggeleder update andelig_visibility" on andelig_visibility for update to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
