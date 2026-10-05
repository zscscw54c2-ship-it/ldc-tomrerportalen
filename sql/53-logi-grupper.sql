-- LDC CG1: Logi-grupper - lar byggeleder sette sammen frivillige som deler én logi (f.eks.
-- ektepar, kjærester, venner som bor sammen), med en fri merkelapp for relasjonen, slik at
-- Logi-koordineringen ikke ser ut som om hver enkelt trenger sin egen logi.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists logi_groups (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  label text,
  relation text,
  created_at timestamptz not null default now()
);
alter table logi_groups enable row level security;
drop policy if exists "read logi_groups" on logi_groups;
create policy "read logi_groups" on logi_groups for select to authenticated using (true);
drop policy if exists "byggeleder write logi_groups" on logi_groups;
create policy "byggeleder write logi_groups" on logi_groups for all to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table logi_groups; exception when duplicate_object then null; end $$;

alter table people add column if not exists logi_group_id uuid references logi_groups(id) on delete set null;

-- Mat-siden varsler om NYE allergier siden matpersonell sist åpnet siden, ved å sammenligne
-- mot dette tidsstempelet (satt eksplisitt av appen når allergi-feltet faktisk endres).
alter table logi_info add column if not exists updated_at timestamptz not null default now();
