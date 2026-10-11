-- P7 (A): Rydd bort gamle rester som ikke lenger brukes.
--
-- Allerede gjort fra verktøyet 11. okt (trenger ikke kjøres):
--   * 6 kontoer slettet: 5 individuelle fag-kontoer som aldri hadde logget inn (landscape, maler,
--     murer, ventilasjon, vvs @cg1.org) + den gamle delte menighetskontoen (kontakt@cg1.org).
--   * search_path satt på check_profile_role() og check_fag_column().
--
-- Denne filen inneholder slettingene ("drop"), som hang når de ble kjørt fra verktøyet. Kjør den i
-- Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.
--
-- Hva som slettes, og hvorfor det er trygt:
--   * user_accounts      - visning som eksponerte auth.users; appen bruker den ikke (tilgang allerede fjernet)
--   * project_invites     - gamle invitasjonslenker (2 ubrukte); invitasjonsflyten er fjernet fra appen
--   * claim_project_invite / get_invite_project_name - funksjonene for invitasjonslenkene
--   * verify_project_code + projects.access_code     - menighetens gamle "lås opp prosjekt"-kode,
--                                                      erstattet av prosjekt + Menighet + kode
--   * fag_trigger_test    - testtabell (4 rader) fra en gammel feilsøking

drop view if exists public.user_accounts;
drop function if exists public.claim_project_invite(text);
drop function if exists public.get_invite_project_name(text);
drop table if exists public.project_invites;
drop function if exists public.verify_project_code(uuid, text);
alter table public.projects drop column if exists access_code;
drop table if exists public.fag_trigger_test;
