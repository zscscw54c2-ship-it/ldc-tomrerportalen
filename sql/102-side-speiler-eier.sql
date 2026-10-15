-- KJØRT 2026-10-15.
-- En CG1-side speiler eieren: innholdet (Office, Godsmottaker, Req prepp) følger avkrysningene til
-- brukeren som eier siden, ikke til den som ser på. Den som har siden krysset av under «Sider»,
-- ser den nøyaktig slik eieren ser den.
--  1) De fire faste sidene kobles til brukeren med samme navn (CGO, ACGO, Kontor 1, Kontor 2).
--  2) Slettes en bruker, slettes bare egne IKKE-faste sider (som før); en fast side blir stående
--     uten eier (fremmednøkkelen blir «on delete set null», og en trigger sletter de andre).
--  3) Tilgangen til Office/Godsmottaker/Req prepp i databasen: egen avkrysning, ELLER tilgang til
--     en side der eieren har avkrysningen.
-- Ingen data slettes eller flyttes.

update public.cg1_pages p set owner_user = a.user_id
  from public.cg1_access a
  where p.fixed and p.owner_user is null and lower(a.display_name) = lower(p.label)
    and not exists (select 1 from public.cg1_pages x where x.owner_user = a.user_id);

alter table public.cg1_pages drop constraint if exists cg1_pages_owner_user_fkey;
alter table public.cg1_pages add constraint cg1_pages_owner_user_fkey
  foreign key (owner_user) references public.cg1_access(user_id) on delete set null;

create or replace function public.cg1_access_owned_pages_cleanup()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.cg1_pages where owner_user = old.user_id and not fixed;
  return old;
end $$;
create or replace trigger cg1_access_owned_pages_cleanup before delete on public.cg1_access
  for each row execute function public.cg1_access_owned_pages_cleanup();

-- Har den innloggede (aktiv) flagget selv, eller tilgang til en side der eieren (aktiv) har det?
create or replace function public.cg1_flag_visible(p_flag text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select (case p_flag when 'office' then a.office when 'godsmottak' then a.godsmottak when 'reqprep' then a.reqprep else false end)
        or exists (
          select 1 from cg1_pages p join cg1_access o on o.user_id = p.owner_user
          where p.key = any(a.pages) and o.active
            and (case p_flag when 'office' then o.office when 'godsmottak' then o.godsmottak when 'reqprep' then o.reqprep else false end))
    from cg1_access a where a.user_id = auth.uid() and a.active), false)
$$;
revoke all on function public.cg1_flag_visible(text) from public, anon;
grant execute on function public.cg1_flag_visible(text) to authenticated;

create or replace function public.current_user_has_office()
returns boolean language sql stable security definer set search_path = public as $$ select public.cg1_flag_visible('office') $$;
create or replace function public.current_user_has_godsmottak()
returns boolean language sql stable security definer set search_path = public as $$ select public.cg1_flag_visible('godsmottak') $$;
create or replace function public.current_user_has_reqprep()
returns boolean language sql stable security definer set search_path = public as $$ select public.cg1_flag_visible('reqprep') $$;
