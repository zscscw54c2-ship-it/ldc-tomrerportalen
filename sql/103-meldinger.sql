-- KJØRT 2026-10-16.
-- Meldinger: samtaler (tråder) mellom CG1-brukere per prosjekt, med vedlegg, og en Req prepp-fane.
-- Vises for brukere med «Meldinger» krysset av (cg1_access.meldinger). Siden speiler eieren
-- (sql/102): den som har en side krysset av, kan LESE eierens samtaler og Req prepp-spørsmål;
-- bare de som er med i tråden kan skrive. Ingen eksisterende data endres.
-- Filer ligger i den private filmappen «meldinger» under <prosjekt-id>/<tråd-id>/.

alter table public.cg1_access add column if not exists meldinger boolean not null default false;

-- Flaggene til sql/102 utvides med «meldinger».
create or replace function public.cg1_flag_visible(p_flag text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select (case p_flag when 'office' then a.office when 'godsmottak' then a.godsmottak when 'reqprep' then a.reqprep when 'meldinger' then a.meldinger else false end)
        or exists (
          select 1 from cg1_pages p join cg1_access o on o.user_id = p.owner_user
          where p.key = any(a.pages) and o.active
            and (case p_flag when 'office' then o.office when 'godsmottak' then o.godsmottak when 'reqprep' then o.reqprep when 'meldinger' then o.meldinger else false end))
    from cg1_access a where a.user_id = auth.uid() and a.active), false)
$$;

-- Kan den innloggede se det brukeren p_user ser i Meldinger? (seg selv, eller eieren av en side
-- den innloggede har krysset av, når eieren har Meldinger)
create or replace function public.msg_can_view_user(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_user = auth.uid() or exists (
    select 1 from cg1_access a join cg1_pages p on p.key = any(a.pages) join cg1_access o on o.user_id = p.owner_user
    where a.user_id = auth.uid() and a.active and o.user_id = p_user and o.active and o.meldinger)
$$;
revoke all on function public.msg_can_view_user(uuid) from public, anon;
grant execute on function public.msg_can_view_user(uuid) to authenticated;

create table if not exists public.msg_threads (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  title text check (char_length(title) <= 80),
  created_by uuid,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);
create index if not exists msg_threads_project on public.msg_threads(project_id);

create table if not exists public.msg_participants (
  thread_id uuid not null references public.msg_threads(id) on delete cascade,
  user_id uuid not null references public.cg1_access(user_id) on delete cascade,
  added_at timestamptz not null default now(),
  last_read_at timestamptz not null default now(),
  primary key (thread_id, user_id)
);
create index if not exists msg_participants_user on public.msg_participants(user_id);

create table if not exists public.msg_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.msg_threads(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  sender uuid,
  sender_name text,
  body text check (char_length(body) <= 4000),
  created_at timestamptz not null default now()
);
create index if not exists msg_messages_thread on public.msg_messages(thread_id, created_at);

create table if not exists public.msg_files (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.msg_messages(id) on delete cascade,
  thread_id uuid not null references public.msg_threads(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  file_path text not null,
  file_name text,
  content_type text,
  created_at timestamptz not null default now()
);
create index if not exists msg_files_message on public.msg_files(message_id);

create or replace function public.msg_is_member(p_thread uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from msg_participants where thread_id = p_thread and user_id = auth.uid())
$$;
create or replace function public.msg_can_read(p_thread uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from msg_participants where thread_id = p_thread and public.msg_can_view_user(user_id))
$$;
create or replace function public.msg_is_creator(p_thread uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from msg_threads where id = p_thread and created_by = auth.uid())
$$;
revoke all on function public.msg_is_member(uuid), public.msg_can_read(uuid), public.msg_is_creator(uuid) from public, anon;
grant execute on function public.msg_is_member(uuid), public.msg_can_read(uuid), public.msg_is_creator(uuid) to authenticated;

-- Avsender og navn settes av databasen; ny melding oppdaterer tråden og avsenderens «lest».
create or replace function public.msg_messages_stamp()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.project_id := (select project_id from msg_threads where id = new.thread_id);
  new.sender := auth.uid();
  new.sender_name := nullif(public.goods_person_name(new.project_id), '');
  return new;
end $$;
create or replace trigger msg_messages_stamp before insert on public.msg_messages
  for each row execute function public.msg_messages_stamp();
create or replace function public.msg_messages_after()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update msg_threads set last_message_at = new.created_at where id = new.thread_id;
  update msg_participants set last_read_at = new.created_at where thread_id = new.thread_id and user_id = new.sender;
  return new;
end $$;
create or replace trigger msg_messages_after after insert on public.msg_messages
  for each row execute function public.msg_messages_after();
create or replace function public.msg_threads_stamp()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then new.created_by := auth.uid(); new.created_at := now(); new.last_message_at := now();
  else new.created_by := old.created_by; new.project_id := old.project_id; new.created_at := old.created_at; end if;
  return new;
end $$;
create or replace trigger msg_threads_stamp before insert or update on public.msg_threads
  for each row execute function public.msg_threads_stamp();

alter table public.msg_threads enable row level security;
alter table public.msg_participants enable row level security;
alter table public.msg_messages enable row level security;
alter table public.msg_files enable row level security;

-- Tråder: lese = deltaker eller speiling; lage = egen Meldinger-avkrysning; endre navn = deltaker;
-- slette = den som laget tråden.
create policy "msg les" on public.msg_threads for select to authenticated using (public.msg_can_read(id) or created_by = auth.uid());
create policy "msg ny" on public.msg_threads for insert to authenticated
  with check (public.can_see_project(project_id) and exists (select 1 from public.cg1_access a where a.user_id = auth.uid() and a.active and a.meldinger));
create policy "msg endre" on public.msg_threads for update to authenticated using (public.msg_is_member(id)) with check (public.msg_is_member(id));
create policy "msg slett" on public.msg_threads for delete to authenticated using (created_by = auth.uid());

-- Deltakere: lese = kan lese tråden; legge til / fjerne = deltaker (eller den som laget tråden);
-- oppdatere = bare egen rad («lest»). Bare brukere med Meldinger kan legges til.
create policy "msg deltakere les" on public.msg_participants for select to authenticated using (public.msg_can_read(thread_id) or public.msg_is_creator(thread_id));
create policy "msg deltakere ny" on public.msg_participants for insert to authenticated
  with check ((public.msg_is_member(thread_id) or public.msg_is_creator(thread_id))
    and exists (select 1 from public.cg1_access a where a.user_id = msg_participants.user_id and a.active and a.meldinger));
create policy "msg deltakere fjern" on public.msg_participants for delete to authenticated using (public.msg_is_member(thread_id));
create policy "msg deltakere lest" on public.msg_participants for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "msg meldinger les" on public.msg_messages for select to authenticated using (public.msg_can_read(thread_id));
create policy "msg meldinger ny" on public.msg_messages for insert to authenticated with check (public.msg_is_member(thread_id));
create policy "msg meldinger slett" on public.msg_messages for delete to authenticated using (sender = auth.uid());

create policy "msg filer les" on public.msg_files for select to authenticated using (public.msg_can_read(thread_id));
create policy "msg filer ny" on public.msg_files for insert to authenticated
  with check (public.msg_is_member(thread_id)
    and exists (select 1 from public.msg_messages m where m.id = message_id and m.thread_id = msg_files.thread_id and m.sender = auth.uid()));
create policy "msg filer slett" on public.msg_files for delete to authenticated
  using (exists (select 1 from public.msg_messages m where m.id = message_id and m.sender = auth.uid()));

revoke all on public.msg_threads, public.msg_participants, public.msg_messages, public.msg_files from anon;
grant select, insert, update, delete on public.msg_threads, public.msg_participants, public.msg_messages, public.msg_files to authenticated;

insert into storage.buckets (id, name, public) values ('meldinger', 'meldinger', false) on conflict (id) do nothing;
create policy "meldinger les" on storage.objects for select to authenticated
  using (bucket_id = 'meldinger' and public.msg_can_read(public.storage_path_second_uuid(name)));
create policy "meldinger last opp" on storage.objects for insert to authenticated
  with check (bucket_id = 'meldinger' and public.msg_is_member(public.storage_path_second_uuid(name)));
create policy "meldinger slett" on storage.objects for delete to authenticated
  using (bucket_id = 'meldinger' and public.msg_is_member(public.storage_path_second_uuid(name)));

-- Req prepp i Meldinger (speiling): den som har en side krysset av, kan lese spørsmålene som er
-- sendt til sidens eier (eierens person under Team) - i tillegg til reglene i sql/100.
create or replace function public.req_visible_via_owner(p_question uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from req_prep_questions q join team_logins t on t.person_id = q.to_person_id and t.project_id = q.project_id
    where q.id = p_question and public.msg_can_view_user(t.account_id))
$$;
revoke all on function public.req_visible_via_owner(uuid) from public, anon;
grant execute on function public.req_visible_via_owner(uuid) to authenticated;
drop policy if exists "req prepp les" on public.req_prep_questions;
create policy "req prepp les" on public.req_prep_questions for select to authenticated
  using ((public.current_user_has_reqprep() and public.can_see_project(project_id)) or public.is_req_recipient(id) or public.req_visible_via_owner(id));
drop policy if exists "req prepp filer" on public.req_prep_files;
create policy "req prepp filer" on public.req_prep_files for all to authenticated
  using ((public.current_user_has_reqprep() and public.can_see_project(project_id)) or public.is_req_recipient(question_id) or public.req_visible_via_owner(question_id))
  with check (((public.current_user_has_reqprep() and public.can_see_project(project_id)) or public.is_req_recipient(question_id))
    and exists (select 1 from public.req_prep_questions q where q.id = question_id and q.project_id = req_prep_files.project_id));
drop policy if exists "reqprep les" on storage.objects;
create policy "reqprep les" on storage.objects for select to authenticated
  using (bucket_id = 'reqprep' and ((public.current_user_has_reqprep() and public.can_see_project(public.storage_path_project_id(name)))
    or public.is_req_recipient(public.storage_path_second_uuid(name)) or public.req_visible_via_owner(public.storage_path_second_uuid(name))));

alter publication supabase_realtime add table public.msg_threads, public.msg_participants, public.msg_messages, public.msg_files;
