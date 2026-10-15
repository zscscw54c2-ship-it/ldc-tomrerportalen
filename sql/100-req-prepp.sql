-- KJØRT 2026-10-15.
-- Req prepp: sjekkliste og spørsmål per prosjekt. Vises for brukere med «Req prepp» krysset av
-- (cg1_access.reqprep), som Office og Godsmottaker. Spørsmål sendes til én person i teamet;
-- personen (innloggingen koblet til personen under Team, team_logins) får varsel og kan svare
-- med tekst og bilder/filer, uten å ha tilgang til selve kortet.
-- Filer ligger i den private filmappen «reqprep» under <prosjekt-id>/<spørsmål-id>/.
-- Ingen eksisterende data endres.

alter table public.cg1_access add column if not exists reqprep boolean not null default false;

create or replace function public.current_user_has_reqprep()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select a.reqprep and a.active from cg1_access a where a.user_id = auth.uid()), false)
$$;
revoke all on function public.current_user_has_reqprep() from public, anon;
grant execute on function public.current_user_has_reqprep() to authenticated;

create table if not exists public.req_prep_items (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 300),
  done boolean not null default false,
  done_at timestamptz,
  done_by text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists req_prep_items_project on public.req_prep_items(project_id);

create table if not exists public.req_prep_questions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  question text not null check (char_length(question) between 1 and 2000),
  to_person_id uuid references public.people(id) on delete set null,
  asked_by uuid,
  asked_by_name text,
  status text not null default 'open' check (status in ('open', 'answered', 'closed')),
  answer text check (char_length(answer) <= 4000),
  answered_at timestamptz,
  answered_by_name text,
  created_at timestamptz not null default now()
);
create index if not exists req_prep_questions_project on public.req_prep_questions(project_id);
create index if not exists req_prep_questions_person on public.req_prep_questions(to_person_id);

create table if not exists public.req_prep_files (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.req_prep_questions(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  file_path text not null,
  file_name text,
  content_type text,
  created_at timestamptz not null default now()
);
create index if not exists req_prep_files_question on public.req_prep_files(question_id);

-- Er den innloggede brukeren mottaker av spørsmålet (koblet til personen i prosjektet)?
create or replace function public.is_req_recipient(p_question uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from req_prep_questions q join team_logins t
      on t.person_id = q.to_person_id and t.project_id = q.project_id
    where q.id = p_question and t.account_id = auth.uid())
$$;
revoke all on function public.is_req_recipient(uuid) from public, anon;
grant execute on function public.is_req_recipient(uuid) to authenticated;

create or replace function public.storage_path_second_uuid(p_name text)
returns uuid language sql immutable set search_path = public as $$
  select case when split_part(p_name, '/', 2) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then split_part(p_name, '/', 2)::uuid end
$$;
grant execute on function public.storage_path_second_uuid(text) to authenticated;

-- Hvem som huket av / spurte / svarte fylles ut av databasen (personens navn, se sql/98).
create or replace function public.req_prep_items_stamp()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if new.done then new.done_at := now(); new.done_by := nullif(public.goods_person_name(new.project_id), ''); end if;
  elsif new.done and not old.done then
    new.done_at := now(); new.done_by := nullif(public.goods_person_name(new.project_id), '');
  elsif not new.done then
    new.done_at := null; new.done_by := null;
  else
    new.done_at := old.done_at; new.done_by := old.done_by;
  end if;
  return new;
end $$;
create or replace trigger req_prep_items_stamp before insert or update on public.req_prep_items
  for each row execute function public.req_prep_items_stamp();

-- Mottakeren (uten Req prepp) kan bare skrive svaret; alt annet holdes som før.
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
  if not public.current_user_has_reqprep() then
    new.question := old.question; new.status := old.status;
    -- (null slippes gjennom: personen ble slettet, «on delete set null»)
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
  -- Ny mottaker: spørsmålet åpnes på nytt.
  if new.to_person_id is distinct from old.to_person_id and new.status <> 'closed' and coalesce(trim(new.answer), '') = '' then
    new.status := 'open';
  end if;
  return new;
end $$;
create or replace trigger req_prep_questions_stamp before insert or update on public.req_prep_questions
  for each row execute function public.req_prep_questions_stamp();

alter table public.req_prep_items enable row level security;
alter table public.req_prep_questions enable row level security;
alter table public.req_prep_files enable row level security;

create policy "req prepp" on public.req_prep_items for all to authenticated
  using (public.current_user_has_reqprep() and public.can_see_project(project_id))
  with check (public.current_user_has_reqprep() and public.can_see_project(project_id));

create policy "req prepp les" on public.req_prep_questions for select to authenticated
  using ((public.current_user_has_reqprep() and public.can_see_project(project_id)) or public.is_req_recipient(id));
create policy "req prepp ny" on public.req_prep_questions for insert to authenticated
  with check (public.current_user_has_reqprep() and public.can_see_project(project_id));
create policy "req prepp endre" on public.req_prep_questions for update to authenticated
  using ((public.current_user_has_reqprep() and public.can_see_project(project_id)) or public.is_req_recipient(id))
  with check ((public.current_user_has_reqprep() and public.can_see_project(project_id)) or public.is_req_recipient(id));
create policy "req prepp slett" on public.req_prep_questions for delete to authenticated
  using (public.current_user_has_reqprep() and public.can_see_project(project_id));

create policy "req prepp filer" on public.req_prep_files for all to authenticated
  using ((public.current_user_has_reqprep() and public.can_see_project(project_id)) or public.is_req_recipient(question_id))
  with check (((public.current_user_has_reqprep() and public.can_see_project(project_id)) or public.is_req_recipient(question_id))
    and exists (select 1 from public.req_prep_questions q where q.id = question_id and q.project_id = req_prep_files.project_id));

revoke all on public.req_prep_items, public.req_prep_questions, public.req_prep_files from anon;
grant select, insert, update, delete on public.req_prep_items, public.req_prep_questions, public.req_prep_files to authenticated;

insert into storage.buckets (id, name, public) values ('reqprep', 'reqprep', false) on conflict (id) do nothing;
create policy "reqprep les" on storage.objects for select to authenticated
  using (bucket_id = 'reqprep' and ((public.current_user_has_reqprep() and public.can_see_project(public.storage_path_project_id(name)))
    or public.is_req_recipient(public.storage_path_second_uuid(name))));
create policy "reqprep last opp" on storage.objects for insert to authenticated
  with check (bucket_id = 'reqprep' and ((public.current_user_has_reqprep() and public.can_see_project(public.storage_path_project_id(name)))
    or public.is_req_recipient(public.storage_path_second_uuid(name))));
create policy "reqprep slett" on storage.objects for delete to authenticated
  using (bucket_id = 'reqprep' and ((public.current_user_has_reqprep() and public.can_see_project(public.storage_path_project_id(name)))
    or public.is_req_recipient(public.storage_path_second_uuid(name))));

alter publication supabase_realtime add table public.req_prep_items, public.req_prep_questions, public.req_prep_files;
