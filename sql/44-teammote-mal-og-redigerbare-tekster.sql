-- LDC CG1: strukturert Teammøte-agenda (mal fra Agenda_32.pdf) + globalt redigerbare tekster på
-- CGO-siden (sjekkliste-ord, e-postmaler, agenda-mal) slik at CGO kan rette tekstene selv.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table team_meetings
  add column if not exists tidspunkt text,
  add column if not exists bonn_ansvarlig text,
  add column if not exists bibelsk_tanke_ansvarlig text,
  add column if not exists ros_takk text,
  add column if not exists praktisk_info text,
  add column if not exists fremdrift text,
  add column if not exists mal_tillegg text,
  add column if not exists ukens_frukt text,
  add column if not exists sporsmal text;

create table if not exists app_text_overrides (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);
alter table app_text_overrides enable row level security;
drop policy if exists "authenticated read app_text_overrides" on app_text_overrides;
create policy "authenticated read app_text_overrides" on app_text_overrides for select to authenticated using (true);
drop policy if exists "byggeleder write app_text_overrides" on app_text_overrides;
create policy "byggeleder write app_text_overrides" on app_text_overrides for all to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table app_text_overrides; exception when duplicate_object then null; end $$;
