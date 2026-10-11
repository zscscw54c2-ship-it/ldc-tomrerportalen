-- P6: «Vis kode» for fag-/menighetskoder i Administrasjon.
--
-- Supabase Auth lagrer bare en hash av passordet, så en kode kan ikke leses tilbake derfra. Når en
-- admin setter en fag-/menighetskode, lagrer Edge Function-en fag-account-admin derfor også koden i
-- klartekst her - i en EGEN tabell (ikke en kolonne i fag_accounts), slik at bare aktiv CG1-admin kan
-- lese den. Ingen kan skrive til tabellen fra nettleseren; kun Edge Function-en (service-rollen).
--
-- Koder som ble satt før dette finnes ikke her (de ble aldri lagret lesbart) - appen viser da
-- «Ukjent – sett ny kode for å kunne vise den». CG1-passord (CGO/ACGO/Kontor) lagres ALDRI her.
-- Raden slettes automatisk hvis prosjektet slettes.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists public.fag_account_codes (
  project_id uuid not null references public.projects(id) on delete cascade,
  fag_key text not null,
  code text not null,
  updated_at timestamptz not null default now(),
  primary key (project_id, fag_key)
);
alter table public.fag_account_codes enable row level security;
drop policy if exists "admin read fag_account_codes" on public.fag_account_codes;
create policy "admin read fag_account_codes" on public.fag_account_codes for select to authenticated
  using (public.current_user_is_cg1_admin());
revoke all on public.fag_account_codes from anon;
