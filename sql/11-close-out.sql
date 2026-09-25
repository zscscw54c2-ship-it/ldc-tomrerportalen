-- LDC - tømrerportalen: eget close out-dato-felt på prosjekter.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table projects add column if not exists close_out_date date;
