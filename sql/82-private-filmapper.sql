-- P5: Gjør filmappene private (tegninger, dokumentasjon, referater, handleliste).
--
-- KJØRES FØRST ETTER at appen med signerte lenker er publisert (commit "P5 (kode): …"). Den gamle
-- appen bruker faste, offentlige lenker, som slutter å virke i det øyeblikket mappene blir private.
--
-- 1) Mappene settes til private: filer kan ikke lenger åpnes av hvem som helst med lenken, bare
--    via tidsbegrensede (signerte) lenker som appen lager for innloggede brukere.
-- 2) Prosjektlås også for filer (som P4): filstien starter alltid med prosjekt-id
--    ("<prosjekt>/<fil>"), så en restriktiv regel krever can_see_project() for den mappen. De
--    eksisterende reglene (innloggede kan lese/laste opp/slette i de fire mappene) er urørt.
--
-- Angre: update storage.buckets set public = true where id in (...); og
--        drop policy "p5 prosjektlås filer" on storage.objects;
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

-- Prosjekt-id fra første del av filstien, eller null hvis den ikke er en gyldig id.
create or replace function public.storage_path_project_id(p_name text)
returns uuid
language sql
immutable
set search_path = public
as $$
  select case when split_part(p_name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then split_part(p_name, '/', 1)::uuid end
$$;
grant execute on function public.storage_path_project_id(text) to anon, authenticated;

update storage.buckets set public = false where id in ('tegninger', 'dokumentasjon', 'referater', 'handleliste');

drop policy if exists "p5 prosjektlås filer" on storage.objects;
create policy "p5 prosjektlås filer" on storage.objects as restrictive for all to public
  using (bucket_id not in ('tegninger', 'dokumentasjon', 'referater', 'handleliste')
         or public.can_see_project(public.storage_path_project_id(name)))
  with check (bucket_id not in ('tegninger', 'dokumentasjon', 'referater', 'handleliste')
         or public.can_see_project(public.storage_path_project_id(name)));
