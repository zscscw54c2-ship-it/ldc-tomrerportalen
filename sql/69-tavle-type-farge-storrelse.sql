-- Kontor 1/Kontor 2 kan nå opprette flere typer tavler (sjekkliste, notat, opplysning),
-- velge farge og størrelse per tavle, slik at de kan sette sammen sitt eget dashbord.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table office_boxes add column if not exists color text;
alter table office_boxes add column if not exists size text not null default 'medium';

alter table office_boxes drop constraint if exists office_boxes_size_check;
alter table office_boxes add constraint office_boxes_size_check check (size in ('small','medium','large'));

alter table office_boxes drop constraint if exists office_boxes_kind_check;
alter table office_boxes add constraint office_boxes_kind_check check (kind in ('checklist','note','info'));
