-- KJØRT 2026-10-14 (i deler). De to gamle Office-tabellene (office_topics, office_week_notes) er også slettet.
-- CG1-sider som admin kan lage selv (f.eks. «Kontor 3»), med avkrysning for hvem som har Office.
--
-- cg1_pages: alle CG1-sider. De fire faste (CGO, ACGO, Kontor 1, Kontor 2) kan ikke slettes.
--   has_office = Office vises på siden, og siden kan være ansvarlig for Office-punkter.
-- Reglene som bare godtok de fire navnene byttes ut:
--   office_boxes.office      -> fremmednøkkel til cg1_pages (tavlene slettes med siden)
--   office_todos.responsible -> fremmednøkkel til cg1_pages (blir tom hvis siden slettes)
--   cg1_access.pages         -> trigger som sjekker at sidene finnes
-- Office (office_todos, office_notes) låses til brukere som har minst én side med Office.
-- Ingen eksisterende data endres.

create table if not exists public.cg1_pages (
  key text primary key check (key ~ '^[a-z0-9_-]{2,40}$'),
  label text not null check (char_length(label) between 1 and 40),
  has_office boolean not null default false,
  fixed boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
insert into public.cg1_pages (key, label, has_office, fixed, sort_order) values
  ('cgo', 'CGO', true, true, 1), ('acgo', 'ACGO', true, true, 2),
  ('kontor1', 'Kontor 1', true, true, 3), ('kontor2', 'Kontor 2', true, true, 4)
on conflict (key) do nothing;

alter table public.cg1_pages enable row level security;
create policy "cg1 les sider" on public.cg1_pages for select to authenticated
  using (public.current_profile_role() = 'byggeleder');
create policy "admin ny side" on public.cg1_pages for insert to authenticated
  with check (public.current_user_is_cg1_admin() and not fixed);
create policy "admin endre side" on public.cg1_pages for update to authenticated
  using (public.current_user_is_cg1_admin()) with check (public.current_user_is_cg1_admin());
create policy "admin slette side" on public.cg1_pages for delete to authenticated
  using (public.current_user_is_cg1_admin() and not fixed);
revoke all on public.cg1_pages from anon;
grant select, insert, update, delete on public.cg1_pages to authenticated;

-- Faste sider kan ikke gjøres om til ikke-faste eller få ny nøkkel.
create or replace function public.cg1_pages_guard()
returns trigger language plpgsql as $$
begin
  if old.fixed and (not new.fixed or new.key <> old.key) then
    raise exception 'Faste CG1-sider kan ikke endres slik';
  end if;
  if not old.fixed and new.fixed then
    raise exception 'Kan ikke gjøre en side fast';
  end if;
  return new;
end $$;
drop trigger if exists cg1_pages_guard on public.cg1_pages;
create trigger cg1_pages_guard before update on public.cg1_pages for each row execute function public.cg1_pages_guard();

-- Tavler og Office-ansvarlig: fremmednøkler i stedet for faste lister.
alter table public.office_boxes drop constraint if exists office_boxes_office_check;
alter table public.office_boxes add constraint office_boxes_office_fkey
  foreign key (office) references public.cg1_pages(key) on update cascade on delete cascade;
alter table public.office_todos drop constraint if exists office_todos_responsible_check;
alter table public.office_todos add constraint office_todos_responsible_fkey
  foreign key (responsible) references public.cg1_pages(key) on update cascade on delete set null;

-- Sidetilganger: hver side i listen må finnes.
alter table public.cg1_access drop constraint if exists cg1_access_pages_check;
create or replace function public.cg1_access_pages_valid()
returns trigger language plpgsql as $$
begin
  if exists (select 1 from unnest(coalesce(new.pages, '{}')) p where not exists (select 1 from public.cg1_pages c where c.key = p)) then
    raise exception 'Ukjent CG1-side i tilgangene';
  end if;
  return new;
end $$;
drop trigger if exists cg1_access_pages_valid on public.cg1_access;
create trigger cg1_access_pages_valid before insert or update on public.cg1_access for each row execute function public.cg1_access_pages_valid();

-- Slettes en side, fjernes den fra alle brukeres tilganger.
create or replace function public.cg1_pages_cleanup()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.cg1_access set pages = array_remove(pages, old.key) where old.key = any(pages);
  return old;
end $$;
drop trigger if exists cg1_pages_cleanup on public.cg1_pages;
create trigger cg1_pages_cleanup before delete on public.cg1_pages for each row execute function public.cg1_pages_cleanup();

-- Office kun for brukere med minst én side som har Office.
create or replace function public.current_user_has_office()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from cg1_access a join cg1_pages p on p.key = any(a.pages)
    where a.user_id = auth.uid() and a.active and p.has_office)
$$;
revoke all on function public.current_user_has_office() from public, anon;
grant execute on function public.current_user_has_office() to authenticated;
create policy "office-tilgang" on public.office_todos as restrictive for all to authenticated
  using (public.current_user_has_office()) with check (public.current_user_has_office());
create policy "office-tilgang" on public.office_notes as restrictive for all to authenticated
  using (public.current_user_has_office()) with check (public.current_user_has_office());

alter publication supabase_realtime add table public.cg1_pages;
