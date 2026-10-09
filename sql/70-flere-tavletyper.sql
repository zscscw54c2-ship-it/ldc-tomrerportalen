-- Kontor 1/Kontor 2-tavler: flere typer (lenker/ressurser, kontaktliste, status/trafikklys, frist),
-- og Notat+Opplysning slås sammen til én "note"-type med en pinned-avkrysning ("Vis som
-- kunngjøring") i stedet for to identiske typer.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table office_boxes add column if not exists pinned boolean not null default false;
alter table office_boxes add column if not exists deadline_date date;

-- Eksisterende "info"-tavler blir til notater som vises som kunngjøring (samme stil som før).
update office_boxes set kind = 'note', pinned = true where kind = 'info';

alter table office_boxes drop constraint if exists office_boxes_kind_check;
alter table office_boxes add constraint office_boxes_kind_check check (kind in ('checklist','note','links','contacts','status','deadline'));

create table if not exists office_box_links (
  id uuid primary key default gen_random_uuid(),
  box_id uuid not null references office_boxes(id) on delete cascade,
  label text not null,
  url text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
alter table office_box_links enable row level security;
drop policy if exists "anon full access office_box_links" on office_box_links;
create policy "anon full access office_box_links" on office_box_links for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table office_box_links; exception when duplicate_object then null; end $$;

create table if not exists office_box_contacts (
  id uuid primary key default gen_random_uuid(),
  box_id uuid not null references office_boxes(id) on delete cascade,
  name text not null,
  phone text,
  email text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
alter table office_box_contacts enable row level security;
drop policy if exists "anon full access office_box_contacts" on office_box_contacts;
create policy "anon full access office_box_contacts" on office_box_contacts for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table office_box_contacts; exception when duplicate_object then null; end $$;

create table if not exists office_box_status_items (
  id uuid primary key default gen_random_uuid(),
  box_id uuid not null references office_boxes(id) on delete cascade,
  text text not null,
  status text not null default 'yellow' check (status in ('red','yellow','green')),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
alter table office_box_status_items enable row level security;
drop policy if exists "anon full access office_box_status_items" on office_box_status_items;
create policy "anon full access office_box_status_items" on office_box_status_items for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table office_box_status_items; exception when duplicate_object then null; end $$;
