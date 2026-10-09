-- LDC CG1: Bygg om leveranser til én tredelt status (usikker/bekreftet/levert, rød/gul/grønn)
-- i stedet for de to separate avkrysningene "usikker dato" og "mottatt". Status redigeres nå
-- sammen med navn og dato i en egen Rediger-dialog på Team-siden.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

alter table deliveries add column if not exists status text not null default 'usikker';

-- Flytt gammel uncertain/received-info over i status FØR de gamle kolonnene fjernes - hoppes
-- over hvis migrasjonen allerede er kjørt (kolonnene finnes da ikke lenger).
do $$ begin
  if exists (select 1 from information_schema.columns where table_name = 'deliveries' and column_name = 'uncertain') then
    update deliveries set status = case
      when received then 'levert'
      when uncertain then 'usikker'
      else 'bekreftet'
    end;
  end if;
end $$;

alter table deliveries drop constraint if exists deliveries_status_check;
alter table deliveries add constraint deliveries_status_check check (status in ('usikker','bekreftet','levert'));

alter table deliveries drop column if exists uncertain;
alter table deliveries drop column if exists received;
alter table deliveries drop column if exists received_date;
