-- Godsmottaker: mottak av varer per prosjekt med dokumenter (følgeseddel, faktura, bilder),
-- avvik og «Behandlet»-avkrysning. Vises for brukere med «Godsmottaker» krysset av
-- (cg1_access.godsmottak), som Office. Alle med Godsmottaker kan legge til, endre og slette.
-- Dokumentene ligger i den private filmappen «godsmottak» under <prosjekt-id>/<mottak-id>/.
-- KJØRT 2026-10-14.

alter table public.cg1_access add column if not exists godsmottak boolean not null default false;

create or replace function public.current_user_has_godsmottak()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select a.godsmottak and a.active from cg1_access a where a.user_id = auth.uid()), false)
$$;
revoke all on function public.current_user_has_godsmottak() from public, anon;
grant execute on function public.current_user_has_godsmottak() to authenticated;

create table if not exists public.goods_receipts (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  received_on date not null default current_date,
  supplier text check (char_length(supplier) <= 120),
  description text check (char_length(description) <= 500),
  fag text,
  deviation text check (char_length(deviation) <= 1000),
  done boolean not null default false,
  done_at timestamptz,
  done_by text,
  created_at timestamptz not null default now()
);
create index if not exists goods_receipts_project on public.goods_receipts(project_id, received_on desc);

create table if not exists public.goods_receipt_files (
  id uuid primary key default gen_random_uuid(),
  receipt_id uuid not null references public.goods_receipts(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  file_path text not null,
  file_name text,
  content_type text,
  created_at timestamptz not null default now()
);
create index if not exists goods_receipt_files_receipt on public.goods_receipt_files(receipt_id);

alter table public.goods_receipts enable row level security;
alter table public.goods_receipt_files enable row level security;
create policy "godsmottaker" on public.goods_receipts for all to authenticated
  using (public.current_user_has_godsmottak() and public.can_see_project(project_id))
  with check (public.current_user_has_godsmottak() and public.can_see_project(project_id));
create policy "godsmottaker" on public.goods_receipt_files for all to authenticated
  using (public.current_user_has_godsmottak() and public.can_see_project(project_id))
  with check (public.current_user_has_godsmottak() and public.can_see_project(project_id));
revoke all on public.goods_receipts, public.goods_receipt_files from anon;
grant select, insert, update, delete on public.goods_receipts, public.goods_receipt_files to authenticated;

insert into storage.buckets (id, name, public) values ('godsmottak', 'godsmottak', false) on conflict (id) do nothing;
create policy "godsmottak les" on storage.objects for select to authenticated
  using (bucket_id = 'godsmottak' and public.current_user_has_godsmottak() and public.can_see_project(public.storage_path_project_id(name)));
create policy "godsmottak last opp" on storage.objects for insert to authenticated
  with check (bucket_id = 'godsmottak' and public.current_user_has_godsmottak() and public.can_see_project(public.storage_path_project_id(name)));
create policy "godsmottak slett" on storage.objects for delete to authenticated
  using (bucket_id = 'godsmottak' and public.current_user_has_godsmottak() and public.can_see_project(public.storage_path_project_id(name)));

alter publication supabase_realtime add table public.goods_receipts;
alter publication supabase_realtime add table public.goods_receipt_files;
