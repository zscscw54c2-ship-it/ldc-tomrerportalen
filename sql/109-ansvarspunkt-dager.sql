-- 109: Ukedager per ansvarspunkt for privilege week (vises i ukelinje på Team-siden).
-- days: 1=mandag … 5=fredag. Tom (null) = gjelder hele uken.
alter table public.spiritual_duties add column if not exists days smallint[];

-- Forslag ut fra teksten (bare punkter som ikke har dager fra før).
update public.spiritual_duties set days = array[5]::smallint[] where days is null and text ~* 'fredag';
update public.spiritual_duties set days = array[4]::smallint[] where days is null and text ~* 'torsdag';
update public.spiritual_duties set days = array[2]::smallint[] where days is null and text ~* 'tirsdag';
update public.spiritual_duties set days = array[3]::smallint[] where days is null and text ~* 'onsdag';
update public.spiritual_duties set days = array[1]::smallint[] where days is null and text ~* 'mandag';

-- Teammøte / familiestudie: dagen fra «Møter og program» i samme prosjekt.
update public.spiritual_duties d set days = array[x.dow]::smallint[]
from (
  select project_id, name,
    case lower(left(trim(time_text), 3)) when 'man' then 1 when 'tir' then 2 when 'ons' then 3 when 'tor' then 4 when 'fre' then 5 end as dow
  from public.spiritual_overview
) x
where d.days is null and x.project_id = d.project_id and x.dow is not null
  and ((d.text ~* 'teammøte' and x.name ~* 'teammøte') or (d.text ~* 'familiestudie' and x.name ~* 'familiestudie'));
