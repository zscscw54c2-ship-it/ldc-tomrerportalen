-- LDC CG1: Dashbord – faste ukentlige tidspunkter for teammøte og TO-møte, per prosjekt.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table projects add column if not exists team_meeting_time text;
alter table projects add column if not exists to_meeting_time text;
