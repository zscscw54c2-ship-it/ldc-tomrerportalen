-- P6: Fjern visningen user_accounts.
--
-- Visningen koblet auth.users (e-postadresser) til profiles og var definert med SECURITY DEFINER -
-- Supabase flagget den som en sikkerhetsfeil ("Exposed Auth Users" / "Security Definer View").
-- Appen trenger den ikke lenger: rolle og koblet person hentes rett fra profiles (byggeleder kan
-- lese alle profiler via eksisterende regel), og e-post til brukerlisten kommer fra Edge Function-en
-- cg1-user-admin (kun for admin).
--
-- KJØRES ETTER at appen som leser fra profiles er publisert (commit "P6: …").
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

drop view if exists public.user_accounts;

-- Status 11. okt: "drop view" hang fra verktøyet som ble brukt, så tilgangen ble i stedet fjernet
-- (samme sikkerhetsgevinst). Selve visningen slettes i P7 / kan slettes med linjen over.
revoke all on public.user_accounts from anon, authenticated;
