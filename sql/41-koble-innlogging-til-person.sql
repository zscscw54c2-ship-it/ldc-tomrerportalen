-- LDC CG1: la ACGO/byggeleder koble en innloggingskonto til et teammedlem (person) direkte i
-- Prosjektinnstillinger, i stedet for å måtte redigere "profiles.person_id" manuelt i databasen.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

-- Vis person_id i brukerlisten på ACGO-/Prosjektinnstillinger-siden.
create or replace view public.user_accounts as
select u.id, u.email, p.role, p.person_id
from auth.users u
join profiles p on p.id = u.id
where current_profile_role() = 'byggeleder';

grant select on public.user_accounts to authenticated;

-- Profiles hadde kun en SELECT-policy; byggeleder trenger UPDATE for å kunne sette person_id
-- fra Brukere-listen.
drop policy if exists "byggeleder update profiles" on profiles;
create policy "byggeleder update profiles" on profiles for update to authenticated
  using (current_profile_role() = 'byggeleder') with check (current_profile_role() = 'byggeleder');
