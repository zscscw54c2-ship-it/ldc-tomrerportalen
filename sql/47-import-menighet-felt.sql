-- Nytt felt på people for import av mannskapsliste (menighet)
alter table people add column if not exists congregation text;
