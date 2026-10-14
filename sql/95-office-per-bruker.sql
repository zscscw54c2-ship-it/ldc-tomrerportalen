-- Office per bruker i stedet for per side (avkrysning ved siden av «Admin» på brukeren).
--  - cg1_access.office: brukeren ser Office (låst i databasen via current_user_has_office()).
--    Settes på for brukere som i dag har en side med Office (CGO, ACGO, Kontor 1, Kontor 2).
--  - office_todos.responsible_user: ansvarlig er en bruker (ikke en side). Eksisterende punkter
--    flyttes fra side til brukeren med samme navn (f.eks. «Kontor 1» -> brukeren «Kontor 1»).
--  - office_todos.responsible og cg1_pages.has_office fjernes.
alter table public.cg1_access add column if not exists office boolean not null default false;
update public.cg1_access a set office = true
  where exists (select 1 from public.cg1_pages p where p.has_office and p.key = any(a.pages));

alter table public.office_todos add column if not exists responsible_user uuid references public.cg1_access(user_id) on delete set null;
update public.office_todos t set responsible_user = a.user_id
  from public.cg1_pages p, public.cg1_access a
  where t.responsible = p.key and lower(a.display_name) = lower(p.label) and t.responsible_user is null;

create or replace function public.current_user_has_office()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select a.office and a.active from cg1_access a where a.user_id = auth.uid()), false)
$$;

-- (kjøres via execute pga. verktøyet) :
alter table public.office_todos drop column responsible;
alter table public.cg1_pages drop column has_office;
