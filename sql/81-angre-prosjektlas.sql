-- Angre P4 (sql/81-prosjektlas.sql): fjerner alle de restriktive prosjektlås-reglene og
-- hjelpefunksjonen. Tilgangen blir da nøyaktig som før P4 (de eksisterende reglene ble aldri endret).
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run.

drop policy if exists "p4 prosjektlås" on public.andelig_visibility;
drop policy if exists "p4 prosjektlås" on public.attendance;
drop policy if exists "p4 prosjektlås" on public.behov_slot;
drop policy if exists "p4 prosjektlås" on public.deliveries;
drop policy if exists "p4 prosjektlås" on public.documentation_photos;
drop policy if exists "p4 prosjektlås" on public.drawings;
drop policy if exists "p4 prosjektlås" on public.elements;
drop policy if exists "p4 prosjektlås" on public.fag_requests;
drop policy if exists "p4 prosjektlås" on public.flex_requests;
drop policy if exists "p4 prosjektlås" on public.logi_groups;
drop policy if exists "p4 prosjektlås" on public.logi_info;
drop policy if exists "p4 prosjektlås" on public.open_accounts;
drop policy if exists "p4 prosjektlås" on public.people;
drop policy if exists "p4 prosjektlås" on public.people_fag_order;
drop policy if exists "p4 prosjektlås" on public.privilege_weeks;
drop policy if exists "p4 prosjektlås" on public.project_fags;
drop policy if exists "p4 prosjektlås" on public.project_startup;
drop policy if exists "p4 prosjektlås" on public.room_todos;
drop policy if exists "p4 prosjektlås" on public.shopping_items;
drop policy if exists "p4 prosjektlås" on public.site_codes;
drop policy if exists "p4 prosjektlås" on public.spiritual_duties;
drop policy if exists "p4 prosjektlås" on public.spiritual_overview;
drop policy if exists "p4 prosjektlås" on public.tasks;
drop policy if exists "p4 prosjektlås" on public.team_meetings;
drop policy if exists "p4 prosjektlås" on public.team_pairs;
drop policy if exists "p4 prosjektlås" on public.to_agenda_items;
drop policy if exists "p4 prosjektlås" on public.to_followups;
drop policy if exists "p4 prosjektlås" on public.to_meetings;
drop policy if exists "p4 prosjektlås" on public.to_safety_log;
drop policy if exists "p4 prosjektlås" on public.to_topics;
drop policy if exists "p4 prosjektlås" on public.weekly_scriptures;
drop policy if exists "p4 prosjektlås" on public.projects;
drop policy if exists "p4 prosjektlås" on public.behov_day;
drop policy if exists "p4 prosjektlås" on public.morning_worship;
drop policy if exists "p4 prosjektlås" on public.privilege_week_duty_status;
drop policy if exists "p4 prosjektlås" on public.to_meeting_attendance;
drop policy if exists "p4 prosjektlås" on public.to_meeting_topic_notes;
drop policy if exists "p4 prosjektlås" on public.to_meeting_fag_status;
drop policy if exists "p4 prosjektlås" on public.office_boxes;
drop policy if exists "p4 prosjektlås" on public.office_box_items;
drop policy if exists "p4 prosjektlås" on public.office_box_links;
drop policy if exists "p4 prosjektlås" on public.office_box_contacts;
drop policy if exists "p4 prosjektlås" on public.office_box_status_items;
drop function if exists public.can_see_project(uuid);
