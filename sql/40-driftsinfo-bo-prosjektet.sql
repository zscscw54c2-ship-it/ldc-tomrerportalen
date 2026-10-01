-- LDC CG1: Fyll inn driftsinfo for Bø-prosjektet (hentet fra gruppebeskrivelsen i Signal-gruppen):
-- losji-adresser for teamet, byggeplass/spisested/møteadresser, wifi-kode, og leverandørkontoer.
-- MERK: UPDATE-linjene for team_pairs bruker faktiske UUID-er fra dette prosjektet. Hvis du kjører
-- dette på et annet Supabase-prosjekt, bytt dem ut med riktige id-er.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run.

update team_pairs set address = 'Saga, 3812 Akkerhaugen' where id = 'f8130c53-faa0-45ba-a5b5-89c56813a711'; -- Sakkestad
update team_pairs set address = 'Liagrendvegen 280, 3812 Akkerhaugen' where id = '9e00fc36-68db-4a58-a581-e60a4d26174f'; -- Ridderberg
update team_pairs set address = 'Valebø 777, 3721 Skien' where id = 'f3b00ec3-3491-48e8-aebe-67ce13fcf179'; -- Bakken
update team_pairs set address = 'Omtvedtvegen 75, 3830 Ulefoss' where id = 'b0287236-9034-4b4b-abb5-0f1209cb223b'; -- Halland

update projects set
  site_address = 'Hørtevegen 22, Gvarv',
  eating_address = 'Gunheim Vel, Gunheimvegen 1, 3810 Gvarv',
  meeting_address = 'Gunheim Vel, Gunheimvegen 1, 3810 Gvarv'
where id = 'ae5a0e64-674a-43d3-b3fe-99f260936496'; -- Bø

insert into site_codes (project_id, label, value) values
  ('ae5a0e64-674a-43d3-b3fe-99f260936496', 'Wifi Kontoret', 'SSID: LDC CG1 · Kode: Huskogbe123');

insert into open_accounts (project_id, leverandor, kundenr, merking) values
  ('ae5a0e64-674a-43d3-b3fe-99f260936496', 'Byggmakker', '4005928', 'OA-1265'),
  ('ae5a0e64-674a-43d3-b3fe-99f260936496', 'Solar', '2104490', 'OA-1260'),
  ('ae5a0e64-674a-43d3-b3fe-99f260936496', 'Lindab', '1582', 'OA-1256'),
  ('ae5a0e64-674a-43d3-b3fe-99f260936496', 'Flügger', '874345', 'OA-1257'),
  ('ae5a0e64-674a-43d3-b3fe-99f260936496', 'Brødrene Dahl', '3002997', 'OA-1262'),
  ('ae5a0e64-674a-43d3-b3fe-99f260936496', 'Avfall', null, 'SC-2752 · Vaskebergvegen 21, Bø'),
  ('ae5a0e64-674a-43d3-b3fe-99f260936496', 'Renta', null, 'SC-2750');
