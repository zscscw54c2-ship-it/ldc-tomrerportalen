-- LDC - tømrerportalen: mulighet for å tildele en person til en rom-/todo-oppgave.
-- Lim hele denne filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table room_todos add column if not exists assigned_person_id uuid references people(id) on delete set null;
