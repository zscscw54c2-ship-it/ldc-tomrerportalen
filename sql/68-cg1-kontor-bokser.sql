-- LDC CG1: Kontor 1 og Kontor 2 får hver sin side under den nye "CG1"-hub-siden, der de selv
-- kan opprette sjekkliste-bokser og infobokser for å lage sin egen skreddersydde side per
-- prosjekt. office_boxes holder selve boksen (sjekkliste eller fri infotekst), office_box_items
-- holder sjekkpunktene for sjekkliste-bokser.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists office_boxes (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  office text not null check (office in ('kontor1','kontor2')),
  kind text not null check (kind in ('checklist','info')),
  title text not null,
  body text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
alter table office_boxes enable row level security;
drop policy if exists "anon full access office_boxes" on office_boxes;
create policy "anon full access office_boxes" on office_boxes for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table office_boxes; exception when duplicate_object then null; end $$;

create table if not exists office_box_items (
  id uuid primary key default gen_random_uuid(),
  box_id uuid not null references office_boxes(id) on delete cascade,
  text text not null,
  done boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
alter table office_box_items enable row level security;
drop policy if exists "anon full access office_box_items" on office_box_items;
create policy "anon full access office_box_items" on office_box_items for all using (true) with check (true);
do $$ begin alter publication supabase_realtime add table office_box_items; exception when duplicate_object then null; end $$;
