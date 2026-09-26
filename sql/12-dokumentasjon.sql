-- LDC - tømrerportalen: database + fillagring for Dokumentasjon (bilder med tekst).
-- Lim hele denne filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists documentation_photos (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  file_path text not null,
  caption text,
  created_at timestamptz not null default now()
);

alter table documentation_photos enable row level security;
drop policy if exists "anon full access documentation_photos" on documentation_photos;
create policy "anon full access documentation_photos" on documentation_photos for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table documentation_photos; exception when duplicate_object then null; end $$;

-- Lagringsrom ("bucket") for selve bildene. Offentlig lesbar, siden siden
-- ikke har innlogging (samme åpne-med-lenke-modell som resten av verktøyet).
insert into storage.buckets (id, name, public)
values ('dokumentasjon', 'dokumentasjon', true)
on conflict (id) do nothing;

drop policy if exists "anon read dokumentasjon" on storage.objects;
create policy "anon read dokumentasjon" on storage.objects
  for select using (bucket_id = 'dokumentasjon');

drop policy if exists "anon upload dokumentasjon" on storage.objects;
create policy "anon upload dokumentasjon" on storage.objects
  for insert with check (bucket_id = 'dokumentasjon');

drop policy if exists "anon delete dokumentasjon" on storage.objects;
create policy "anon delete dokumentasjon" on storage.objects
  for delete using (bucket_id = 'dokumentasjon');
