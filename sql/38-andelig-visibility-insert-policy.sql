-- LDC CG1: "Vis Team-siden for" bruker nå upsert (siden nye prosjekter ikke har rader fra før),
-- men det fantes bare en UPDATE-policy, ingen INSERT. Det ga "new row violates row-level
-- security policy" når man krysset av for et prosjekt uten eksisterende rader (f.eks. et nytt
-- prosjekt opprettet etter sql/37). Lim hele filen inn i Supabase > SQL Editor > New query.

create policy "byggeleder insert andelig_visibility" on andelig_visibility
  for insert to authenticated with check (current_profile_role() = 'byggeleder');
