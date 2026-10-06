-- LDC CG1: Handlelisten rydder nå automatisk vekk varer som har vært huket av som "kjøpt" i
-- over 1 døgn, så listen ikke fylles opp med gamle, ferdig-handlede varer. Appen stempler
-- bought_at når en vare merkes kjøpt, og feier bort varer der det er over 24 timer siden.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table shopping_items add column if not exists bought_at timestamptz;

-- Varer som allerede står som kjøpt (fra før denne kolonnen fantes) får et bought_at satt til nå,
-- så de ikke blir stående "for alltid" fordi de mangler tidsstempelet - de ryddes bort ved neste feiing.
update shopping_items set bought_at = now() where bought = true and bought_at is null;
