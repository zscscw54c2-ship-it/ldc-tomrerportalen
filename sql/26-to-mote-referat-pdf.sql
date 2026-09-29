-- LDC CG1: PDF-referat for TO-møte, generert og lastet opp når møtet avsluttes.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table to_meetings add column if not exists referat_pdf_path text;

insert into storage.buckets (id, name, public)
values ('referater', 'referater', true)
on conflict (id) do nothing;

drop policy if exists "anon read referater" on storage.objects;
create policy "anon read referater" on storage.objects
  for select using (bucket_id = 'referater');

drop policy if exists "anon upload referater" on storage.objects;
create policy "anon upload referater" on storage.objects
  for insert with check (bucket_id = 'referater');

drop policy if exists "anon delete referater" on storage.objects;
create policy "anon delete referater" on storage.objects
  for delete using (bucket_id = 'referater');
