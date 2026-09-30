-- LDC CG1: koble team-par til en person (så de kan vises i "Frivillige etter fag"
-- under en egen "Teamet"-kategori, med samme rutenett som andre fag), egen
-- "Koder"-seksjon for byggeplassen (wifi, kodelås osv.) i stedet for per-par,
-- og flytter OPEN ACCOUNTS til Team-siden.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table team_pairs add column if not exists person_id uuid references people(id) on delete set null;
alter table team_pairs drop column if exists codes;

create table if not exists site_codes (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  label text not null,
  value text not null,
  created_at timestamptz not null default now()
);
alter table site_codes enable row level security;
drop policy if exists "anon full access site_codes" on site_codes;
create policy "anon full access site_codes" on site_codes for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table site_codes; exception when duplicate_object then null; end $$;

alter table attendance drop constraint if exists attendance_fag_check;
alter table attendance add constraint attendance_fag_check
  check (fag in ('tomrer','vvs','maler','elektriker','landscape','murer','ventilasjon','stillas','audio_video','behov_menighet','team'));
