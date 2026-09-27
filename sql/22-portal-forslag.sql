-- LDC CG1: "Forslag til endringer i portalen" – ACGO/byggeleder kan legge inn
-- ønsker/forslag til hva som bør endres eller legges til i selve portalen.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists portal_suggestions (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  created_at timestamptz not null default now()
);
alter table portal_suggestions enable row level security;
drop policy if exists "authenticated read portal_suggestions" on portal_suggestions;
create policy "authenticated read portal_suggestions" on portal_suggestions for select to authenticated using (true);
drop policy if exists "byggeleder insert portal_suggestions" on portal_suggestions;
create policy "byggeleder insert portal_suggestions" on portal_suggestions for insert to authenticated
  with check (current_profile_role() = 'byggeleder');
drop policy if exists "byggeleder delete portal_suggestions" on portal_suggestions;
create policy "byggeleder delete portal_suggestions" on portal_suggestions for delete to authenticated
  using (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table portal_suggestions; exception when duplicate_object then null; end $$;
