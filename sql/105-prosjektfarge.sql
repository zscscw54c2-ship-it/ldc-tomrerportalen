-- KJØRT 2026-10-16.
-- Prosjektfarge (velges under «Rediger prosjekt»), så man ser hvilket prosjekt man står i.
-- Tom = portalen velger en farge automatisk. Ingen eksisterende data endres.
alter table public.projects add column if not exists color text check (color ~ '^#[0-9a-fA-F]{6}$');
