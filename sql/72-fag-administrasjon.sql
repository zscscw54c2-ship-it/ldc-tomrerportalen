-- Fag-administrasjon: fagene (tømrer, VVS osv.) flyttes fra hardkodede lister i koden og faste
-- database-sjekker til en egen "fags"-tabell, slik at byggeleder kan opprette og slette fag -
-- og sette egen farge på hvert fag - direkte i portalen, uten at noen må endre kode eller kjøre
-- SQL manuelt for hvert nye fag.
--
-- De 10 tabellene som tidligere hadde en fast CHECK (fag IN (...)) får i stedet en trigger som
-- sjekker verdien mot "fags"-tabellen (pluss et lite sett faste, strukturelle kategorier som
-- stillas/audio_video/behov_menighet/team/byggeleder/kontakt, som ikke er ordentlige fag og ikke
-- skal kunne slettes).
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists fags (
  key text primary key,
  label text not null,
  color text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
alter table fags enable row level security;
drop policy if exists "authenticated read fags" on fags;
create policy "authenticated read fags" on fags for select to authenticated using (true);
drop policy if exists "byggeleder write fags" on fags;
create policy "byggeleder write fags" on fags for all to authenticated using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table fags; exception when duplicate_object then null; end $$;

insert into fags (key, label, color, sort_order) values
  ('tomrer', 'Tømrer', '#2f6fa8', 0),
  ('vvs', 'VVS', '#1fa38e', 1),
  ('maler', 'Maler', '#d69a1f', 2),
  ('elektriker', 'Elektrikker', '#d2503d', 3),
  ('landscape', 'Landscape', '#5fa84a', 4),
  ('murer', 'Murer', '#8a6d4f', 5),
  ('ventilasjon', 'Ventilasjon', '#6f8fd1', 6),
  ('blikkenslager', 'Blikkenslager', '#c1793f', 7),
  ('ovrig', 'Øvrig', '#4a3a2e', 8)
on conflict (key) do nothing;

-- Generisk trigger-funksjon for kolonner som heter "fag": godtar enten en gyldig rad i "fags",
-- eller en av de faste ekstra-verdiene gitt som argument til triggeren (TG_ARGV), eller NULL
-- (for kolonner som tillater det, f.eks. behov_slot.fag).
create or replace function check_fag_column() returns trigger as $fn$
declare
  i integer;
  allowed boolean;
begin
  if NEW.fag is null then
    return NEW;
  end if;
  select exists(select 1 from fags where key = NEW.fag) into allowed;
  if not allowed then
    for i in 0 .. TG_NARGS - 1 loop
      if NEW.fag = TG_ARGV[i] then
        allowed := true;
        exit;
      end if;
    end loop;
  end if;
  if not allowed then
    raise exception 'Ugyldig fag: %', NEW.fag;
  end if;
  return NEW;
end;
$fn$ language plpgsql;

create or replace function check_profile_role() returns trigger as $fn$
declare
  allowed boolean;
begin
  if NEW.role in ('byggeleder', 'kontakt') then
    return NEW;
  end if;
  select exists(select 1 from fags where key = NEW.role) into allowed;
  if not allowed then
    raise exception 'Ugyldig rolle: %', NEW.role;
  end if;
  return NEW;
end;
$fn$ language plpgsql;

alter table andelig_visibility drop constraint if exists andelig_visibility_fag_check;
drop trigger if exists fag_ref_check on andelig_visibility;
create trigger fag_ref_check before insert or update on andelig_visibility for each row execute function check_fag_column();

alter table attendance drop constraint if exists attendance_fag_check;
drop trigger if exists fag_ref_check on attendance;
create trigger fag_ref_check before insert or update on attendance for each row execute function check_fag_column('stillas', 'audio_video', 'behov_menighet', 'team');

alter table behov_slot drop constraint if exists behov_slot_fag_check;
drop trigger if exists fag_ref_check on behov_slot;
create trigger fag_ref_check before insert or update on behov_slot for each row execute function check_fag_column();

alter table documentation_photos drop constraint if exists documentation_photos_fag_check;
drop trigger if exists fag_ref_check on documentation_photos;
create trigger fag_ref_check before insert or update on documentation_photos for each row execute function check_fag_column();

alter table drawings drop constraint if exists drawings_fag_check;
drop trigger if exists fag_ref_check on drawings;
create trigger fag_ref_check before insert or update on drawings for each row execute function check_fag_column('stillas');

alter table elements drop constraint if exists elements_fag_check;
drop trigger if exists fag_ref_check on elements;
create trigger fag_ref_check before insert or update on elements for each row execute function check_fag_column('stillas', 'audio_video', 'behov_menighet');

alter table project_fags drop constraint if exists project_fags_fag_check;
drop trigger if exists fag_ref_check on project_fags;
create trigger fag_ref_check before insert or update on project_fags for each row execute function check_fag_column();

alter table shopping_items drop constraint if exists shopping_items_fag_check;
drop trigger if exists fag_ref_check on shopping_items;
create trigger fag_ref_check before insert or update on shopping_items for each row execute function check_fag_column();

alter table to_meeting_fag_status drop constraint if exists to_meeting_fag_status_fag_check;
drop trigger if exists fag_ref_check on to_meeting_fag_status;
create trigger fag_ref_check before insert or update on to_meeting_fag_status for each row execute function check_fag_column();

alter table profiles drop constraint if exists profiles_role_check;
drop trigger if exists profile_role_check on profiles;
create trigger profile_role_check before insert or update on profiles for each row execute function check_profile_role();
