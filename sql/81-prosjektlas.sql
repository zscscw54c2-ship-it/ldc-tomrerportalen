-- P4: Lås delte fag-/menighetskontoer til sitt eget prosjekt - i DATABASEN, ikke bare i appen.
--
-- Før: alle innloggede (også de delte kodekontoene) kunne lese alle personer (telefon, adresse,
-- allergier) og alle data i alle prosjekter; appen skjulte bare de andre prosjektene. Tabellen
-- "elements" kunne i tillegg leses uten innlogging (leseregel for rollen public).
--
-- Løsning: én RESTRIKTIV regel per prosjekt-tabell. Restriktive regler kommer I TILLEGG til de
-- eksisterende ("og du må ha tilgang til prosjektet") - ingen eksisterende regel endres, og angring
-- er bare å fjerne de nye (se sql/81-angre-prosjektlas.sql).
--
-- can_see_project(prosjekt):
--   * byggeleder (CGO/ACGO/Kontor)             -> alle prosjekter
--   * konto med profiles.project_id satt        -> bare det prosjektet (delte fag-/menighetskontoer)
--   * gammel individuell konto (project_id null) -> alle, som før (ryddes bort i P7)
--   * ikke innlogget / uten profil              -> ingen
-- CG1-tavlene (office_box*) er bare for byggeleder.
--
-- Funksjoner som går forbi RLS med vilje (fill_behov_day, list_projects_public osv.) og Edge
-- Functions med service-rollen påvirkes ikke.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create or replace function public.can_see_project(p_project uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select case
      when p.role = 'byggeleder' then true
      when p.project_id is null then true
      else p.project_id = p_project
    end
    from profiles p where p.id = auth.uid()
  ), false)
$$;
-- anon må også kunne kalle den (den gir alltid false uten innlogging) - ellers gir reglene en
-- "permission denied"-feil i stedet for bare å skjule radene.
revoke all on function public.can_see_project(uuid) from public;
grant execute on function public.can_see_project(uuid) to anon, authenticated;

drop policy if exists "p4 prosjektlås" on public.andelig_visibility;
create policy "p4 prosjektlås" on public.andelig_visibility as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.attendance;
create policy "p4 prosjektlås" on public.attendance as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.behov_slot;
create policy "p4 prosjektlås" on public.behov_slot as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.deliveries;
create policy "p4 prosjektlås" on public.deliveries as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.documentation_photos;
create policy "p4 prosjektlås" on public.documentation_photos as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.drawings;
create policy "p4 prosjektlås" on public.drawings as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.elements;
create policy "p4 prosjektlås" on public.elements as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.fag_requests;
create policy "p4 prosjektlås" on public.fag_requests as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.flex_requests;
create policy "p4 prosjektlås" on public.flex_requests as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.logi_groups;
create policy "p4 prosjektlås" on public.logi_groups as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.logi_info;
create policy "p4 prosjektlås" on public.logi_info as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.open_accounts;
create policy "p4 prosjektlås" on public.open_accounts as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.people;
create policy "p4 prosjektlås" on public.people as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.people_fag_order;
create policy "p4 prosjektlås" on public.people_fag_order as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.privilege_weeks;
create policy "p4 prosjektlås" on public.privilege_weeks as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.project_fags;
create policy "p4 prosjektlås" on public.project_fags as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.project_startup;
create policy "p4 prosjektlås" on public.project_startup as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.room_todos;
create policy "p4 prosjektlås" on public.room_todos as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.shopping_items;
create policy "p4 prosjektlås" on public.shopping_items as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.site_codes;
create policy "p4 prosjektlås" on public.site_codes as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.spiritual_duties;
create policy "p4 prosjektlås" on public.spiritual_duties as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.spiritual_overview;
create policy "p4 prosjektlås" on public.spiritual_overview as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.tasks;
create policy "p4 prosjektlås" on public.tasks as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.team_meetings;
create policy "p4 prosjektlås" on public.team_meetings as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.team_pairs;
create policy "p4 prosjektlås" on public.team_pairs as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.to_agenda_items;
create policy "p4 prosjektlås" on public.to_agenda_items as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.to_followups;
create policy "p4 prosjektlås" on public.to_followups as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.to_meetings;
create policy "p4 prosjektlås" on public.to_meetings as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.to_safety_log;
create policy "p4 prosjektlås" on public.to_safety_log as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.to_topics;
create policy "p4 prosjektlås" on public.to_topics as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.weekly_scriptures;
create policy "p4 prosjektlås" on public.weekly_scriptures as restrictive for all to public
  using (public.can_see_project(project_id))
  with check (public.can_see_project(project_id));

drop policy if exists "p4 prosjektlås" on public.projects;
create policy "p4 prosjektlås" on public.projects as restrictive for all to public
  using (public.can_see_project(id))
  with check (public.can_see_project(id));

drop policy if exists "p4 prosjektlås" on public.behov_day;
create policy "p4 prosjektlås" on public.behov_day as restrictive for all to public
  using (exists (select 1 from public.behov_slot s where s.id = behov_day.slot_id and public.can_see_project(s.project_id)))
  with check (exists (select 1 from public.behov_slot s where s.id = behov_day.slot_id and public.can_see_project(s.project_id)));

drop policy if exists "p4 prosjektlås" on public.morning_worship;
create policy "p4 prosjektlås" on public.morning_worship as restrictive for all to public
  using (exists (select 1 from public.privilege_weeks w where w.id = morning_worship.privilege_week_id and public.can_see_project(w.project_id)))
  with check (exists (select 1 from public.privilege_weeks w where w.id = morning_worship.privilege_week_id and public.can_see_project(w.project_id)));

drop policy if exists "p4 prosjektlås" on public.privilege_week_duty_status;
create policy "p4 prosjektlås" on public.privilege_week_duty_status as restrictive for all to public
  using (exists (select 1 from public.privilege_weeks w where w.id = privilege_week_duty_status.privilege_week_id and public.can_see_project(w.project_id)))
  with check (exists (select 1 from public.privilege_weeks w where w.id = privilege_week_duty_status.privilege_week_id and public.can_see_project(w.project_id)));

drop policy if exists "p4 prosjektlås" on public.to_meeting_attendance;
create policy "p4 prosjektlås" on public.to_meeting_attendance as restrictive for all to public
  using (exists (select 1 from public.to_meetings m where m.id = to_meeting_attendance.meeting_id and public.can_see_project(m.project_id)))
  with check (exists (select 1 from public.to_meetings m where m.id = to_meeting_attendance.meeting_id and public.can_see_project(m.project_id)));

drop policy if exists "p4 prosjektlås" on public.to_meeting_topic_notes;
create policy "p4 prosjektlås" on public.to_meeting_topic_notes as restrictive for all to public
  using (exists (select 1 from public.to_meetings m where m.id = to_meeting_topic_notes.meeting_id and public.can_see_project(m.project_id)))
  with check (exists (select 1 from public.to_meetings m where m.id = to_meeting_topic_notes.meeting_id and public.can_see_project(m.project_id)));

drop policy if exists "p4 prosjektlås" on public.to_meeting_fag_status;
create policy "p4 prosjektlås" on public.to_meeting_fag_status as restrictive for all to public
  using (exists (select 1 from public.to_meetings m where m.id = to_meeting_fag_status.meeting_id and public.can_see_project(m.project_id)))
  with check (exists (select 1 from public.to_meetings m where m.id = to_meeting_fag_status.meeting_id and public.can_see_project(m.project_id)));

drop policy if exists "p4 prosjektlås" on public.office_boxes;
create policy "p4 prosjektlås" on public.office_boxes as restrictive for all to public
  using (public.current_profile_role() = 'byggeleder')
  with check (public.current_profile_role() = 'byggeleder');

drop policy if exists "p4 prosjektlås" on public.office_box_items;
create policy "p4 prosjektlås" on public.office_box_items as restrictive for all to public
  using (public.current_profile_role() = 'byggeleder')
  with check (public.current_profile_role() = 'byggeleder');

drop policy if exists "p4 prosjektlås" on public.office_box_links;
create policy "p4 prosjektlås" on public.office_box_links as restrictive for all to public
  using (public.current_profile_role() = 'byggeleder')
  with check (public.current_profile_role() = 'byggeleder');

drop policy if exists "p4 prosjektlås" on public.office_box_contacts;
create policy "p4 prosjektlås" on public.office_box_contacts as restrictive for all to public
  using (public.current_profile_role() = 'byggeleder')
  with check (public.current_profile_role() = 'byggeleder');

drop policy if exists "p4 prosjektlås" on public.office_box_status_items;
create policy "p4 prosjektlås" on public.office_box_status_items as restrictive for all to public
  using (public.current_profile_role() = 'byggeleder')
  with check (public.current_profile_role() = 'byggeleder');

