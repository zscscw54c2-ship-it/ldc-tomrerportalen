-- KJØRT 2026-10-16.
-- Req prepp: samtale (tråd) under hvert spørsmål. Etter første svar kan avsender og mottaker
-- fortsette å skrive. Svar fra mottakeren -> «Besvart»; ny melding fra avsenderen -> «Venter på svar».
-- Lukket spørsmål tar ikke imot flere svar. Lesing som spørsmålet (sql/104). Vedlegg kan kobles til
-- et svar (req_prep_files.reply_id). Eksisterende data endres ikke.

create table if not exists public.req_prep_replies (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.req_prep_questions(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  sender uuid,
  sender_name text,
  body text check (char_length(body) <= 4000),
  created_at timestamptz not null default now()
);
create index if not exists req_prep_replies_question on public.req_prep_replies(question_id, created_at);
alter table public.req_prep_files add column if not exists reply_id uuid references public.req_prep_replies(id) on delete cascade;

create or replace function public.req_prep_replies_stamp()
returns trigger language plpgsql security definer set search_path = public as $$
declare q record;
begin
  select * into q from req_prep_questions where id = new.question_id;
  if q.status = 'closed' then raise exception 'Spørsmålet er lukket'; end if;
  new.project_id := q.project_id;
  new.sender := auth.uid();
  new.sender_name := nullif(public.goods_person_name(q.project_id), '');
  new.created_at := now();
  return new;
end $$;
create or replace trigger req_prep_replies_stamp before insert on public.req_prep_replies
  for each row execute function public.req_prep_replies_stamp();

-- Status følger hvem som skrev sist (systemoppdatering forbi reglene i req_prep_questions_stamp).
create or replace function public.req_prep_replies_after()
returns trigger language plpgsql security definer set search_path = public as $$
declare q record;
begin
  select * into q from req_prep_questions where id = new.question_id;
  perform set_config('app.req_system', '1', true);
  if new.sender = q.asked_by then
    update req_prep_questions set status = 'open' where id = new.question_id;
  else
    update req_prep_questions set status = 'answered', answered_at = new.created_at, answered_by_name = new.sender_name where id = new.question_id;
  end if;
  perform set_config('app.req_system', '', true);
  return new;
end $$;
create or replace trigger req_prep_replies_after after insert on public.req_prep_replies
  for each row execute function public.req_prep_replies_after();

create or replace function public.req_prep_questions_stamp()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.asked_by := auth.uid();
    new.asked_by_name := nullif(public.goods_person_name(new.project_id), '');
    new.status := 'open'; new.answer := null; new.answered_at := null; new.answered_by_name := null;
    return new;
  end if;
  if coalesce(current_setting('app.req_system', true), '') = '1' then return new; end if;
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

alter table public.req_prep_replies enable row level security;
create policy "req svar les" on public.req_prep_replies for select to authenticated using (public.req_can_read(question_id));
create policy "req svar ny" on public.req_prep_replies for insert to authenticated
  with check (public.req_is_asker(question_id) or public.is_req_recipient(question_id));
create policy "req svar slett" on public.req_prep_replies for delete to authenticated using (sender = auth.uid());
revoke all on public.req_prep_replies from anon;
grant select, insert, delete on public.req_prep_replies to authenticated;
alter publication supabase_realtime add table public.req_prep_replies;
