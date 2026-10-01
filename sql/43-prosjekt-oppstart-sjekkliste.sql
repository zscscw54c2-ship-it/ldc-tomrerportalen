-- LDC CG1: digitaliserer CGOs "Mal til nytt prosjekt" som en sjekkliste på CGO-siden - fylles ut
-- og krysses av per prosjekt (Precon / Før oppstart / Close out), i stedet for et separat dokument.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists project_startup (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  item_key text not null,
  done boolean not null default false,
  value text,
  updated_at timestamptz not null default now(),
  unique(project_id, item_key)
);
alter table project_startup enable row level security;
drop policy if exists "byggeleder full access project_startup" on project_startup;
create policy "byggeleder full access project_startup" on project_startup for all to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table project_startup; exception when duplicate_object then null; end $$;
