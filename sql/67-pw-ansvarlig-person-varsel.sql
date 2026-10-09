-- LDC CG1: Kobler privilege-ukens "ansvarlig" til en faktisk person (ikke bare fritekst),
-- slik at appen kan kjenne igjen at DEN innloggede personen har privilege week denne uken og
-- varsle om manglende bemanning i morgentilbedelsen/sikkerhetstalen. Fritekstfeltet
-- (responsible) beholdes uendret for visning - det er kun en ekstra kobling i tillegg.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table privilege_weeks add column if not exists responsible_person_id uuid references people(id) on delete set null;
