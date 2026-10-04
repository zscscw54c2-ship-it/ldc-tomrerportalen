-- Nye felt på people for import av mannskapsliste (telefon, adresse)
alter table people add column if not exists phone text;
alter table people add column if not exists address text;
