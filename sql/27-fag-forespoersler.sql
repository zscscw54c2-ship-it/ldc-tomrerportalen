-- LDC CG1: forespørsler fra fag om å endre tilgjengelighet i "frivillige etter fag",
-- som ACGO kan godkjenne eller avslå. Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run.
-- Trygt å kjøre flere ganger.

create table if not exists fag_requests (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  fag text not null,
  person_id uuid references people(id) on delete cascade,
  day date not null,
  desired_present boolean not null,
  status text not null default 'pending',
  requested_by text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

alter table fag_requests enable row level security;
drop policy if exists "anon full access fag_requests" on fag_requests;
create policy "anon full access fag_requests" on fag_requests for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table fag_requests; exception when duplicate_object then null; end $$;
