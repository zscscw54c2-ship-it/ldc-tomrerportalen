-- LDC CG1: "Andre behov" – behov som ikke hører til et bestemt fag (f.eks. "kjøre søppel").
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists behov_extra (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  description text not null,
  day date,
  person_id uuid references people(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table behov_extra enable row level security;
drop policy if exists "authenticated read behov_extra" on behov_extra;
create policy "authenticated read behov_extra" on behov_extra for select to authenticated using (true);
drop policy if exists "byggeleder insert behov_extra" on behov_extra;
create policy "byggeleder insert behov_extra" on behov_extra for insert to authenticated
  with check (current_profile_role() = 'byggeleder');
drop policy if exists "byggeleder delete behov_extra" on behov_extra;
create policy "byggeleder delete behov_extra" on behov_extra for delete to authenticated
  using (current_profile_role() = 'byggeleder');
drop policy if exists "kontakt or byggeleder update behov_extra" on behov_extra;
create policy "kontakt or byggeleder update behov_extra" on behov_extra for update to authenticated
  using (current_profile_role() in ('kontakt','byggeleder')) with check (current_profile_role() in ('kontakt','byggeleder'));
do $$ begin alter publication supabase_realtime add table behov_extra; exception when duplicate_object then null; end $$;
