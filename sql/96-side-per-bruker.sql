-- KJØRT 2026-10-14. Siden følger brukeren: cg1_pages.owner_user = brukeren siden ble laget for
-- (tom for de fire faste). Slettes brukeren, slettes siden (og tavlene på den) automatisk.
-- Brukerfunksjonen cg1-user-admin lager siden når brukeren opprettes og gir den nytt navn med brukeren.
alter table public.cg1_pages add column if not exists owner_user uuid unique references public.cg1_access(user_id) on delete cascade;
-- Brukeren «Kontor 3» (laget før dette) får sin side:
insert into public.cg1_pages (key, label, fixed, sort_order, owner_user)
  select 'kontor3', 'Kontor 3', false, 5, user_id from public.cg1_access where display_name = 'Kontor 3'
  on conflict (key) do nothing;
update public.cg1_access set pages = array_append(pages, 'kontor3') where display_name = 'Kontor 3' and not ('kontor3' = any(pages));
