-- LDC CG1: "OPEN ACCOUNTS" - leverandørkontoer med kundenr og merking, på Frivillige-siden.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists open_accounts (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  leverandor text not null,
  kundenr text,
  merking text,
  created_at timestamptz not null default now()
);
alter table open_accounts enable row level security;
drop policy if exists "anon full access open_accounts" on open_accounts;
create policy "anon full access open_accounts" on open_accounts for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table open_accounts; exception when duplicate_object then null; end $$;
