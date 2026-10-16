-- KJØRT 2026-10-16.
-- Req prepp-spørsmål er private mellom avsender og mottaker.
--  Lese: avsender, mottaker (innloggingen koblet til personen under Team), og den som speiler en av
--        dem via en side de har krysset av (sql/102).
--  Endre (lukke/åpne igjen, endre spørsmålet): avsender. Mottakeren kan bare skrive svaret.
--  Slette: avsender.
--  Filer: lese som spørsmålet; legge til/fjerne: avsender eller mottaker.
-- Sjekklisten er fortsatt felles for alle med Req prepp. Ingen data endres.

-- Kan den innloggede se det brukeren p_user ser (seg selv, eller eieren av en side man har)?
create or replace function public.cg1_can_view_user(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_user = auth.uid() or exists (
    select 1 from cg1_access a join cg1_pages p on p.key = any(a.pages) join cg1_access o on o.user_id = p.owner_user
    where a.user_id = auth.uid() and a.active and o.user_id = p_user and o.active)
$$;
revoke all on function public.cg1_can_view_user(uuid) from public, anon;
grant execute on function public.cg1_can_view_user(uuid) to authenticated;

create or replace function public.req_is_asker(p_question uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from req_prep_questions where id = p_question and asked_by = auth.uid())
$$;
create or replace function public.req_can_read(p_question uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from req_prep_questions q
    where q.id = p_question and (
      public.cg1_can_view_user(q.asked_by)
      or exists (select 1 from team_logins t where t.person_id = q.to_person_id and t.project_id = q.project_id and public.cg1_can_view_user(t.account_id))))
$$;
revoke all on function public.req_is_asker(uuid), public.req_can_read(uuid) from public, anon;
grant execute on function public.req_is_asker(uuid), public.req_can_read(uuid) to authenticated;

-- Bare avsenderen kan endre spørsmålet/status; alle andre (mottakeren) kan bare skrive svaret.
create or replace function public.req_prep_questions_stamp()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.asked_by := auth.uid();
    new.asked_by_name := nullif(public.goods_person_name(new.project_id), '');
    new.status := 'open'; new.answer := null; new.answered_at := null; new.answered_by_name := null;
    return new;
  end if;
  new.asked_by := old.asked_by; new.asked_by_name := old.asked_by_name; new.project_id := old.project_id;
  if old.asked_by is distinct from auth.uid() then
    new.question := old.question; new.status := old.status;
    if new.to_person_id is not null then new.to_person_id := old.to_person_id; end if;
    if coalesce(new.answer, '') is distinct from coalesce(old.answer, '') then
      if old.status = 'closed' then raise exception 'Spørsmålet er lukket'; end if;
      if coalesce(trim(new.answer), '') <> '' then new.status := 'answered'; end if;
    end if;
  end if;
  if coalesce(new.answer, '') is distinct from coalesce(old.answer, '') then
    if coalesce(trim(new.answer), '') <> '' then
      new.answered_at := now();
      new.answered_by_name := nullif(public.goods_person_name(new.project_id), '');
      if new.status = 'open' then new.status := 'answered'; end if;
    end if;
  else
    new.answered_at := old.answered_at; new.answered_by_name := old.answered_by_name;
  end if;
  if new.to_person_id is distinct from old.to_person_id and new.status <> 'closed' and coalesce(trim(new.answer), '') = '' then
    new.status := 'open';
  end if;
  return new;
end $$;

drop policy if exists "req prepp les" on public.req_prep_questions;
drop policy if exists "req prepp endre" on public.req_prep_questions;
drop policy if exists "req prepp slett" on public.req_prep_questions;
-- (radens egne kolonner brukes direkte, så den nye raden også er synlig ved insert ... returning)
create policy "req prepp les" on public.req_prep_questions for select to authenticated
  using (public.cg1_can_view_user(asked_by)
    or exists (select 1 from public.team_logins t where t.person_id = req_prep_questions.to_person_id and t.project_id = req_prep_questions.project_id and public.cg1_can_view_user(t.account_id)));
create policy "req prepp endre" on public.req_prep_questions for update to authenticated
  using (asked_by = auth.uid() or public.is_req_recipient(id)) with check (asked_by = auth.uid() or public.is_req_recipient(id));
create policy "req prepp slett" on public.req_prep_questions for delete to authenticated using (asked_by = auth.uid());

drop policy if exists "req prepp filer" on public.req_prep_files;
create policy "req prepp filer les" on public.req_prep_files for select to authenticated using (public.req_can_read(question_id));
create policy "req prepp filer ny" on public.req_prep_files for insert to authenticated
  with check ((public.req_is_asker(question_id) or public.is_req_recipient(question_id))
    and exists (select 1 from public.req_prep_questions q where q.id = question_id and q.project_id = req_prep_files.project_id));
create policy "req prepp filer slett" on public.req_prep_files for delete to authenticated
  using (public.req_is_asker(question_id) or public.is_req_recipient(question_id));

drop policy if exists "reqprep les" on storage.objects;
drop policy if exists "reqprep last opp" on storage.objects;
drop policy if exists "reqprep slett" on storage.objects;
create policy "reqprep les" on storage.objects for select to authenticated
  using (bucket_id = 'reqprep' and public.req_can_read(public.storage_path_second_uuid(name)));
create policy "reqprep last opp" on storage.objects for insert to authenticated
  with check (bucket_id = 'reqprep' and (public.req_is_asker(public.storage_path_second_uuid(name)) or public.is_req_recipient(public.storage_path_second_uuid(name))));
create policy "reqprep slett" on storage.objects for delete to authenticated
  using (bucket_id = 'reqprep' and (public.req_is_asker(public.storage_path_second_uuid(name)) or public.is_req_recipient(public.storage_path_second_uuid(name))));
