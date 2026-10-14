-- Forslag til endringer i portalen: punkter som kan krysses av. Avkryssede forslag slettes av
-- portalen 24 timer etter avkrysning (done_at), som handlelistens kjøpte varer.
-- Nye kolonner (eksisterende forslag blir «ikke krysset av») + en regel som lar CG1 krysse av
-- (tabellen hadde bare lese-, legg til- og slette-regler).
alter table public.portal_suggestions add column if not exists done boolean not null default false;
alter table public.portal_suggestions add column if not exists done_at timestamptz;
create policy "byggeleder update portal_suggestions" on public.portal_suggestions for update to authenticated
  using (public.current_profile_role() = 'byggeleder') with check (public.current_profile_role() = 'byggeleder');
grant update on public.portal_suggestions to authenticated;

-- Angre: drop policy "byggeleder update portal_suggestions" on public.portal_suggestions;
--        alter table public.portal_suggestions drop column done, drop column done_at;
