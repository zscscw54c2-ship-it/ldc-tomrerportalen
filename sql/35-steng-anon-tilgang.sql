-- LDC CG1: Sikkerhetsrettelse - steng tilgang for uinnloggede (anon) brukere.
-- Flere tabeller og alle storage-buckets (tegninger, dokumentasjon, referater) hadde policyer
-- som i praksis gjaldt ALLE roller, inkludert helt uinnloggede forespørsler direkte mot
-- Supabase sitt REST-/Storage-API (dvs. uten å noensinne logge inn i selve portalen).
-- Det betydde at hvem som helst med prosjektets offentlige URL + anon-nøkkel (som ligger
-- åpent i nettsidens kildekode, slik det må for at appen skal virke i det hele tatt) kunne
-- lese og skrive disse tabellene og slette filer - blant annet byggeplasskoder (wifi/kodelås)
-- og leverandørkontonumre. Denne migrasjonen strammer alt til kun innloggede brukere,
-- slik resten av databasen allerede fungerte. Lim hele filen inn i Supabase > SQL Editor >
-- New query, og trykk Run. Trygt å kjøre flere ganger.

drop policy if exists "anon full access fag_requests" on fag_requests;
create policy "authenticated full access fag_requests" on fag_requests for all to authenticated using (true) with check (true);

drop policy if exists "anon full access flex_requests" on flex_requests;
create policy "authenticated full access flex_requests" on flex_requests for all to authenticated using (true) with check (true);

drop policy if exists "anon full access open_accounts" on open_accounts;
create policy "authenticated full access open_accounts" on open_accounts for all to authenticated using (true) with check (true);

drop policy if exists "anon full access site_codes" on site_codes;
create policy "authenticated full access site_codes" on site_codes for all to authenticated using (true) with check (true);

drop policy if exists "anon full access team_meetings" on team_meetings;
create policy "authenticated full access team_meetings" on team_meetings for all to authenticated using (true) with check (true);

drop policy if exists "anon full access team_pairs" on team_pairs;
create policy "authenticated full access team_pairs" on team_pairs for all to authenticated using (true) with check (true);

drop policy if exists "anon full access weekly_scriptures" on weekly_scriptures;
create policy "authenticated full access weekly_scriptures" on weekly_scriptures for all to authenticated using (true) with check (true);

-- Defense-in-depth: user_accounts-viewet er allerede beskyttet av en WHERE-klausul
-- (kun byggeleder-rollen får rader), men er en SECURITY DEFINER-view som Postgres
-- sin linter flagger som eksponert mot anon-rollen på rettighetsnivå. Fjern den
-- rettigheten eksplisitt så det ikke avhenger av at WHERE-logikken forblir korrekt.
revoke all on public.user_accounts from anon;
grant select on public.user_accounts to authenticated;

-- Storage: samme problem, gjaldt lesing, opplasting OG SLETTING av filer.
drop policy if exists "anon delete dokumentasjon" on storage.objects;
drop policy if exists "anon delete referater" on storage.objects;
drop policy if exists "anon delete tegninger" on storage.objects;
drop policy if exists "anon read dokumentasjon" on storage.objects;
drop policy if exists "anon read referater" on storage.objects;
drop policy if exists "anon read tegninger" on storage.objects;
drop policy if exists "anon upload dokumentasjon" on storage.objects;
drop policy if exists "anon upload referater" on storage.objects;
drop policy if exists "anon upload tegninger" on storage.objects;

create policy "authenticated read dokumentasjon" on storage.objects for select to authenticated using (bucket_id = 'dokumentasjon');
create policy "authenticated upload dokumentasjon" on storage.objects for insert to authenticated with check (bucket_id = 'dokumentasjon');
create policy "authenticated delete dokumentasjon" on storage.objects for delete to authenticated using (bucket_id = 'dokumentasjon');

create policy "authenticated read referater" on storage.objects for select to authenticated using (bucket_id = 'referater');
create policy "authenticated upload referater" on storage.objects for insert to authenticated with check (bucket_id = 'referater');
create policy "authenticated delete referater" on storage.objects for delete to authenticated using (bucket_id = 'referater');

create policy "authenticated read tegninger" on storage.objects for select to authenticated using (bucket_id = 'tegninger');
create policy "authenticated upload tegninger" on storage.objects for insert to authenticated with check (bucket_id = 'tegninger');
create policy "authenticated delete tegninger" on storage.objects for delete to authenticated using (bucket_id = 'tegninger');
