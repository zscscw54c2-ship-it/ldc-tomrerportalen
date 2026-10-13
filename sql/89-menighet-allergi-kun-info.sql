-- Menigheten (rolle 'kontakt') kan se allergiene i logi_info, men ikke endre dem. Bare CG1
-- (byggeleder) fører allergier. Menigheten kan fortsatt lagre adresse, vertsfamilie, telefon,
-- kommentar og status som før.
--
-- Gjøres med en trigger (RLS kan ikke sammenligne gammel og ny verdi i én kolonne). Gjelder
-- alle allergifeltene: allergier (gammelt), allergi_mat, allergi_logi, allergi_mat_tekst og
-- allergi_logi_tekst. Tom tekst og null regnes som det samme.
--
-- INSERT … ON CONFLICT (upsert, som appen bruker): finnes raden fra før, blir det en oppdatering, og
-- da sjekker BEFORE UPDATE-triggeren de faktiske nye verdiene. Insert-sjekken gjelder derfor bare
-- helt nye rader: der må allergifeltene være tomme.
--
-- Trygt å kjøre flere ganger.

create or replace function public.logi_info_lock_allergies()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.logi_info%rowtype;
begin
  if coalesce(public.current_profile_role(), '') <> 'kontakt' then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    o := old;
  elsif exists (select 1 from public.logi_info where project_id = new.project_id and person_id = new.person_id) then
    return new; -- upsert mot eksisterende rad: sjekkes i BEFORE UPDATE
  end if; -- ny rad: o er tom, så alle allergifelt må være tomme
  if coalesce(new.allergier, '') <> coalesce(o.allergier, '')
     or coalesce(new.allergi_mat_tekst, '') <> coalesce(o.allergi_mat_tekst, '')
     or coalesce(new.allergi_logi_tekst, '') <> coalesce(o.allergi_logi_tekst, '')
     or coalesce(new.allergi_mat, false) <> coalesce(o.allergi_mat, false)
     or coalesce(new.allergi_logi, false) <> coalesce(o.allergi_logi, false) then
    raise exception 'Allergier kan bare endres av CG1' using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function public.logi_info_lock_allergies() from public, anon, authenticated;

drop trigger if exists logi_info_lock_allergies on public.logi_info;
create trigger logi_info_lock_allergies
  before insert or update on public.logi_info
  for each row execute function public.logi_info_lock_allergies();

-- Angre: drop trigger logi_info_lock_allergies on public.logi_info;
--        drop function public.logi_info_lock_allergies();
