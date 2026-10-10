-- LDC CG1: Brukere og tilganger for CGO, ACGO, Kontor 1 og Kontor 2, styrt fra Administrasjon.
--
-- Alle CG1-brukere har fortsatt rollen "byggeleder" i profiles, så ALLE eksisterende
-- tilgangsregler (RLS) virker akkurat som før. cg1_access legger på tre ting i tillegg:
--   * pages    - hvilke CG1-sider brukeren ser (cgo, acgo, kontor1, kontor2)
--   * is_admin - om brukeren ser Administrasjon og kan styre brukere/tilganger
--   * active   - deaktiverte brukere stenges også ute i Auth (Edge Function cg1-user-admin)
--
-- Tabellen kan LESES av byggeleder (appen trenger egen rad, admin trenger alle), men kan IKKE
-- endres fra nettleseren - kun via Edge Function-en cg1-user-admin (service-rollen), som selv
-- sjekker at den som ringer er admin.
--
-- Startoppsett for eksisterende byggeleder-kontoer: alle beholder tilgang til alle fire sidene
-- akkurat som i dag, og cgo@cg1.org blir admin. CGO velger så selv i Administrasjon hvem som skal
-- se hvilke sider, og kan gi admin videre (f.eks. til ACGO).
--
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create table if not exists cg1_access (
  user_id uuid primary key references profiles(id) on delete cascade,
  display_name text,
  pages text[] not null default '{}',
  is_admin boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cg1_access_pages_check check (pages <@ array['cgo','acgo','kontor1','kontor2']::text[])
);
alter table cg1_access enable row level security;
drop policy if exists "byggeleder read cg1_access" on cg1_access;
create policy "byggeleder read cg1_access" on cg1_access for select to authenticated
  using (current_profile_role() = 'byggeleder');
revoke all on cg1_access from anon;
do $$ begin alter publication supabase_realtime add table cg1_access; exception when duplicate_object then null; end $$;

-- Startoppsett (rører ikke rader som allerede finnes).
insert into cg1_access (user_id, display_name, pages, is_admin)
select p.id,
  case u.email
    when 'cgo@cg1.org' then 'CGO'
    when 'acgo@cg1.org' then 'ACGO'
    when 'kontor1@cg1.org' then 'Kontor 1'
    when 'kontor2@cg1.org' then 'Kontor 2'
    else null end,
  array['cgo','acgo','kontor1','kontor2'],
  u.email = 'cgo@cg1.org'
from profiles p
join auth.users u on u.id = p.id
where p.role = 'byggeleder'
on conflict (user_id) do nothing;

-- Brukes av andre Edge Functions/regler som trenger "er innringeren CG1-admin?".
create or replace function current_user_is_cg1_admin()
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select exists(select 1 from cg1_access where user_id = auth.uid() and is_admin and active)
$$;
grant execute on function current_user_is_cg1_admin() to authenticated;
