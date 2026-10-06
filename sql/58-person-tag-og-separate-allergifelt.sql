-- LDC CG1: To utvidelser:
-- 1) people.tag - fritekst-"tag" på en frivillig (f.eks. "Lokal" eller "Under 18"), vist som en
--    liten merkelapp bak navnet i Frivillige-listen, "Søk i listen" og Logi-listen.
-- 2) Allergier/diett splittes i to HELT separate kommentarfelt (mat og logi) i stedet for ett delt
--    tekstfelt + to avkrysninger - gir mer presis og uavhengig informasjon til kjøkken og
--    vertsfamilier. Gamle allergier/allergi_mat/allergi_logi-kolonner rører vi ikke (de blir
--    bakoverkompatibelt stående ubrukt), men innholdet deres kopieres inn i de nye feltene først.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table people add column if not exists tag text;

alter table logi_info add column if not exists allergi_mat_tekst text;
alter table logi_info add column if not exists allergi_logi_tekst text;

update logi_info set allergi_mat_tekst = allergier
  where allergi_mat_tekst is null and allergi_mat = true and allergier is not null and btrim(allergier) <> '';
update logi_info set allergi_logi_tekst = allergier
  where allergi_logi_tekst is null and allergi_logi = true and allergier is not null and btrim(allergier) <> '';
