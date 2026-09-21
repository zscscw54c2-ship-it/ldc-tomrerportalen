-- LDC - tømrerportalen: database + fillagring for Tegninger.
-- Lim hele denne filen inn i Supabase > SQL Editor > New query, og trykk Run.
-- (Kjøres i tillegg til de to foregående SQL-filene.)

-- Metadata-tabell for opplastede tegninger/bilder/PDF-er
create table if not exists drawings (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  name text not null,
  file_path text not null,
  content_type text,
  size_bytes bigint,
  created_at timestamptz not null default now()
);

alter table drawings enable row level security;

drop policy if exists "anon full access drawings" on drawings;
create policy "anon full access drawings" on drawings
  for all using (true) with check (true);

alter publication supabase_realtime add table drawings;

-- Lagringsrom ("bucket") for selve filene. Offentlig lesbar, siden siden
-- ikke har innlogging (samme åpne-med-lenke-modell som resten av verktøyet).
insert into storage.buckets (id, name, public)
values ('tegninger', 'tegninger', true)
on conflict (id) do nothing;

drop policy if exists "anon read tegninger" on storage.objects;
create policy "anon read tegninger" on storage.objects
  for select using (bucket_id = 'tegninger');

drop policy if exists "anon upload tegninger" on storage.objects;
create policy "anon upload tegninger" on storage.objects
  for insert with check (bucket_id = 'tegninger');

drop policy if exists "anon delete tegninger" on storage.objects;
create policy "anon delete tegninger" on storage.objects
  for delete using (bucket_id = 'tegninger');
