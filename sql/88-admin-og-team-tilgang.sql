-- 1) Redigering kun for admin, 2) To-do med samme tilgang som Team-siden.
--
-- Alle regler her er RESTRIKTIVE og kommer i tillegg til de som finnes (ingen slettes): en rad må
-- passere både de gamle reglene og disse.
--
-- 1) Det som bare kan endres i redigeringsmodus («Rediger»-knappen, som nå bare vises for admin):
--      app_text_overrides  (redigerbare tekster)      – skriving kun admin
--      spiritual_overview  (Åndelig program / Møter)   – skriving kun admin
--      weekly_scriptures   (ukens skriftsted)          – skriving kun admin
--      drawings            (endre navn / slette)       – update/delete kun admin, opplasting som før
--      documentation_photos (endre tekst / slette)     – update/delete kun admin, opplasting som før
--    CG1-tavlene (office_box*) låses IKKE her: avkrysning/status brukes daglig av alle CG1-brukere og
--    ligger i de samme tabellene. Tavlene er uansett bare for CG1 (byggeleder).
--
-- 2) can_see_team(prosjekt): samme sjekk som Team-siden i appen (canSeeTeamPages): CG1 (byggeleder)
--    alltid; ellers bare når innloggingen er koblet til en person som er krysset av i teamet i
--    prosjektet (team_logins, sql/86). Brukes av To-do (room_todos).
--
-- Trygt å kjøre flere ganger (bortsett fra «create policy», som feiler hvis regelen finnes - det er greit).

create or replace function public.can_see_team(p_project uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select case when p.role = 'byggeleder' then true
                else exists (select 1 from team_logins tl join people pe on pe.id = tl.person_id
                             where tl.account_id = auth.uid() and tl.project_id = p_project and pe.on_team)
           end
    from profiles p where p.id = auth.uid()), false)
$$;
revoke all on function public.can_see_team(uuid) from public, anon;
grant execute on function public.can_see_team(uuid) to authenticated;

-- 2) To-do
create policy "p10 team-tilgang" on public.room_todos as restrictive for all to authenticated
  using (public.can_see_team(project_id)) with check (public.can_see_team(project_id));

-- 1) Kun admin skriver
create policy "p10 admin ins" on public.app_text_overrides as restrictive for insert to authenticated with check (public.current_user_is_cg1_admin());
create policy "p10 admin upd" on public.app_text_overrides as restrictive for update to authenticated using (public.current_user_is_cg1_admin()) with check (public.current_user_is_cg1_admin());
create policy "p10 admin del" on public.app_text_overrides as restrictive for delete to authenticated using (public.current_user_is_cg1_admin());

create policy "p10 admin ins" on public.spiritual_overview as restrictive for insert to authenticated with check (public.current_user_is_cg1_admin());
create policy "p10 admin upd" on public.spiritual_overview as restrictive for update to authenticated using (public.current_user_is_cg1_admin()) with check (public.current_user_is_cg1_admin());
create policy "p10 admin del" on public.spiritual_overview as restrictive for delete to authenticated using (public.current_user_is_cg1_admin());

create policy "p10 admin ins" on public.weekly_scriptures as restrictive for insert to authenticated with check (public.current_user_is_cg1_admin());
create policy "p10 admin upd" on public.weekly_scriptures as restrictive for update to authenticated using (public.current_user_is_cg1_admin()) with check (public.current_user_is_cg1_admin());
create policy "p10 admin del" on public.weekly_scriptures as restrictive for delete to authenticated using (public.current_user_is_cg1_admin());

create policy "p10 admin upd" on public.drawings as restrictive for update to authenticated using (public.current_user_is_cg1_admin()) with check (public.current_user_is_cg1_admin());
create policy "p10 admin del" on public.drawings as restrictive for delete to authenticated using (public.current_user_is_cg1_admin());

create policy "p10 admin upd" on public.documentation_photos as restrictive for update to authenticated using (public.current_user_is_cg1_admin()) with check (public.current_user_is_cg1_admin());
create policy "p10 admin del" on public.documentation_photos as restrictive for delete to authenticated using (public.current_user_is_cg1_admin());

-- Filene bak tegninger og dokumentasjonsbilder: sletting kun admin (ellers kunne filen slettes selv om
-- raden ble stående). Opplasting som før. Sletting av hele prosjektet går via service-rollen.
create policy "p10 admin slett filer" on storage.objects as restrictive for delete to authenticated
  using (bucket_id not in ('tegninger', 'dokumentasjon') or public.current_user_is_cg1_admin());

-- Angre: drop policy "p10 …" on <tabell>; (for hver regel over) og drop function public.can_see_team(uuid);
