-- Innloggingssiden må kunne vise "velg hvilket fag du skal logge inn som" FØR noen er innlogget,
-- men "fags"-tabellen er (riktig nok) kun lesbar for "authenticated" - det er nettopp denne
-- typen åpning til "anon" som ble stengt i sql/71. I stedet for å åpne hele tabellen for anon,
-- følger denne en allerede etablert vei i appen (se get_invite_project_name i
-- sql/42-logi-og-menighetsinvitasjon.sql): en liten, security definer-funksjon som bare
-- eksponerer de feltene som uansett ikke er sensitive (navn og farge på et fag).
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

create or replace function list_fags_public()
returns table (key text, label text, color text, sort_order integer)
language sql
stable security definer
set search_path = public
as $$
  select key, label, color, sort_order from fags order by sort_order
$$;
grant execute on function list_fags_public() to anon, authenticated;
