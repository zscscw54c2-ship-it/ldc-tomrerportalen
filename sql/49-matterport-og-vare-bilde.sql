-- Matterport-lenke/passord på prosjektet, og mulighet for bilde på en vare i handlelisten.
alter table projects add column if not exists matterport_url text;
alter table projects add column if not exists matterport_password text;
alter table shopping_items add column if not exists image_path text;

-- Lagringsrom for varebilder i handlelisten, samme mønster som dokumentasjon/tegninger.
insert into storage.buckets (id, name, public)
values ('handleliste', 'handleliste', true)
on conflict (id) do nothing;

drop policy if exists "authenticated read handleliste" on storage.objects;
create policy "authenticated read handleliste" on storage.objects for select to authenticated using (bucket_id = 'handleliste');
drop policy if exists "authenticated upload handleliste" on storage.objects;
create policy "authenticated upload handleliste" on storage.objects for insert to authenticated with check (bucket_id = 'handleliste');
drop policy if exists "authenticated delete handleliste" on storage.objects;
create policy "authenticated delete handleliste" on storage.objects for delete to authenticated using (bucket_id = 'handleliste');
