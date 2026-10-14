-- KJØRT 2026-10-14.
-- Godsmottaker: «Lagt inn av» og «Behandlet av» med personens navn.
-- Navnet er personen innloggingen er koblet til under Team i prosjektet (team_logins -> people),
-- ellers brukerens navn (cg1_access.display_name). Fylles ut av databasen, ikke av nettleseren.
-- Eksisterende mottak får ikke «lagt inn av» (ukjent hvem).

alter table public.goods_receipts add column if not exists created_by uuid;
alter table public.goods_receipts add column if not exists created_by_name text;
alter table public.goods_receipts add column if not exists done_by_user uuid;

create or replace function public.goods_person_name(p_project uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select p.name from team_logins t join people p on p.id = t.person_id
      where t.account_id = auth.uid() and t.project_id = p_project and nullif(trim(p.name), '') is not null
      order by t.created_at limit 1),
    (select a.display_name from cg1_access a where a.user_id = auth.uid()),
    '')
$$;
revoke all on function public.goods_person_name(uuid) from public, anon;
grant execute on function public.goods_person_name(uuid) to authenticated;

create or replace function public.goods_receipts_stamp()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    new.created_by_name := nullif(public.goods_person_name(new.project_id), '');
    if new.done then
      new.done_at := coalesce(new.done_at, now());
      new.done_by_user := auth.uid();
      new.done_by := nullif(public.goods_person_name(new.project_id), '');
    end if;
  else
    new.created_by := old.created_by;
    new.created_by_name := old.created_by_name;
    if new.done and not old.done then
      new.done_at := now();
      new.done_by_user := auth.uid();
      new.done_by := nullif(public.goods_person_name(new.project_id), '');
    elsif not new.done then
      new.done_at := null; new.done_by_user := null; new.done_by := null;
    else
      new.done_at := old.done_at; new.done_by_user := old.done_by_user; new.done_by := old.done_by;
    end if;
  end if;
  return new;
end $$;
create or replace trigger goods_receipts_stamp before insert or update on public.goods_receipts
  for each row execute function public.goods_receipts_stamp();
