-- To-do: avhukede punkter slettes automatisk 2 døgn etter avhuking.
-- done_at = når punktet ble huket av (null når det ikke er huket av). Portalen setter/nullstiller
-- feltet ved avhuking og sletter punkter med done_at eldre enn 48 timer (som handlelistens bought_at).
-- Punkter som allerede er huket av får tidspunktet nå, så de slettes tidligst om to døgn.
-- Trygt å kjøre flere ganger.
alter table public.room_todos add column if not exists done_at timestamptz;
update public.room_todos set done_at = now() where done and done_at is null;

-- Angre: alter table public.room_todos drop column done_at;
