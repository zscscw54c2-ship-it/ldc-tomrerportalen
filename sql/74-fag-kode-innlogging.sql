-- Fase 4 (database-delen): delte fag-kontoer med kode satt av byggeleder i portalen, som et
-- alternativ TIL SIDEN FOR dagens individuelle kontoer (ikke en erstatning - byggeleder slår av
-- de gamle kontoene selv, i eget tempo, når de er klare).
--
-- "fag_accounts" kobler et fag (fra fags-tabellen) til ÉN delt Supabase Auth-bruker. Selve
-- opprettelsen og kode-endringen (= passordet på denne brukeren) gjøres av en Edge Function med
-- service-rollen (se fag-account-admin), aldri direkte fra nettleseren - derfor ingen
-- skrive-policy her for "authenticated", kun lesing for byggeleder.
--
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists fag_accounts (
  fag_key text primary key references fags(key) on delete cascade,
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table fag_accounts enable row level security;
drop policy if exists "byggeleder read fag_accounts" on fag_accounts;
create policy "byggeleder read fag_accounts" on fag_accounts for select to authenticated
  using (current_profile_role() = 'byggeleder');
do $$ begin alter publication supabase_realtime add table fag_accounts; exception when duplicate_object then null; end $$;

-- Utvider team-medlemskapet (brukt av logi_info) til også å telle en delt fag-konto som
-- teammedlem, når faget har "Vis Team-siden for" (andelig_visibility.visible) satt til sant
-- (eller ikke satt noe sted ennå - samme standardverdi som appen selv bruker). Vanlige
-- individuelle kontoer (med person_id) er uendret fra forrige migrasjon.
create or replace function current_profile_is_team_member()
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select exists (
    select 1 from profiles p
    join people pp on pp.id = p.person_id
    where p.id = auth.uid() and pp.on_team = true
  )
  or exists (
    select 1 from profiles p
    join fag_accounts fa on fa.auth_user_id = p.id and fa.fag_key = p.role
    where p.id = auth.uid()
      and p.person_id is null
      and coalesce((select av.visible from andelig_visibility av where av.fag = p.role limit 1), true) = true
  )
$$;
