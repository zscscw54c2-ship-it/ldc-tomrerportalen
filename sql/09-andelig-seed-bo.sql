-- LDC - tømrerportalen: eksempeldata for "Bø"-prosjektet, hentet fra "Åndelig skjema"-arket.
-- Kjør 08-andelig.sql først. Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run.
-- Trygt å kjøre flere ganger.

do $$
declare pid uuid;
begin
  select id into pid from projects where name = 'Bø' or name ilike 'Bø%' order by created_at limit 1;
  if pid is null then
    return;
  end if;

  update projects set spiritual_info = 'Høsten er tid for kretsstevne, og vi er ganske nærme Oslo stevnehall og sørlandet.
Sjekk hvilket dere vil ta på jw.org <3'
  where id = pid and (spiritual_info is null or spiritual_info = '');

  insert into spiritual_duties (project_id, text, sort_order)
  select pid, v.text, v.ord
  from (values
    ('Starte streaming',1),('Lede & skrive risikoanalyse',2),('Inn & ut-sjekkings',3),
    ('Sikkerhetstale (tirsdag)',4),('Åndelig tanke teammøte',5),('Napo (torsdag)',6),
    ('Sikkerhetsrunde (torsdag)',7),('Lede familiestudie',8),('Live MW (fredag)',9),
    ('Avslutte med sang – fredag',10)
  ) as v(text, ord)
  where not exists (select 1 from spiritual_duties d where d.project_id = pid and d.text = v.text);

  insert into spiritual_overview (project_id, kind, name, time_text, ansvarlig, sort_order)
  select pid, v.kind, v.name, v.time_text, v.ansvarlig, v.ord
  from (values
    ('program','Familiestudie','Tirsdag 17:15',null,1),
    ('program','Midtukemøte','Torsdag 19:00',null,2),
    ('program','Helgemøte','Søndag 17:00',null,3),
    ('program','Felttjeneste','Søndag 13:00 + gruppevis lørdager',null,4),
    ('mote','TO-møte','Tirsdag 11:30','Robin Ridderberg',1),
    ('mote','Teammøte','Onsdag 13:00','Jonathan Sakkestad',2)
  ) as v(kind, name, time_text, ansvarlig, ord)
  where not exists (select 1 from spiritual_overview o where o.project_id = pid and o.kind = v.kind and o.name = v.name);

  insert into privilege_weeks (project_id, start_date, end_date, responsible, label, familiestudie, sikkerhetstale, bibellesning, note)
  select pid, v.s::date, v.e::date, v.resp, v.label, v.fam, v.sik, v.bib, v.note
  from (values
    ('2026-08-31','2026-09-04','Sakkestad','Oppstartsuke','Live',null,null,null),
    ('2026-09-07','2026-09-11','Ridderberg',null,'Stream Holbæk','J1','Jer 36:20-32',null),
    ('2026-09-14','2026-09-18','Halland',null,'Live','A5','Jer 38:14-28',null),
    ('2026-09-21','2026-09-25','Bakken',null,'Live','B5','Jer 40:7-16','Torsdag WTP – Victor'),
    ('2026-09-28','2026-10-02','Sakkestad',null,'Stream Holbæk','C4','Jer 43:1-13',null),
    ('2026-10-05','2026-10-09','Ridderberg',null,'Live','J2','Jer 46:1-9',null),
    ('2026-10-12','2026-10-16','Halland',null,'Live + lecture («Spirits for holy service»)','C1','Jer 48:1-13',null),
    ('2026-10-19','2026-10-23','Bakken',null,'Stream Holbæk','C9','Jer 49:23-39','Torsdag WTP – Joni'),
    ('2026-10-26','2026-10-30','Sakkestad','Close out uke','Live',null,null,null)
  ) as v(s,e,resp,label,fam,sik,bib,note)
  where not exists (select 1 from privilege_weeks w where w.project_id = pid and w.start_date = v.s::date);
end $$;
