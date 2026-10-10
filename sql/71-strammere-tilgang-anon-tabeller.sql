-- Sikkerhetsfiks: 6 tabeller (deliveries + alle Kontor-tavle-tabellene) ble satt opp med
-- "anon full access"-policyer (rolle "public") da de ble laget, i stedet for det samme
-- "authenticated"-mønsteret resten av databasen allerede bruker konsekvent. Det betyr at
-- disse 6 tabellene i praksis er åpne for hvem som helst på internett, innlogget eller ikke -
-- alle andre tabeller krever allerede en gyldig innlogget økt (se f.eks. policyene på
-- room_todos/tasks/spiritual_duties for samme mønster).
--
-- Denne migrasjonen bytter rollen fra "public" til "authenticated" på disse 6 tabellene, uten
-- å endre noe annet - alle innloggede roller (byggeleder/kontakt/team/menighet) beholder nøyaktig
-- samme tilgang som før, siden "authenticated full access"-mønsteret allerede er det normale
-- for tilsvarende tabeller i resten av appen.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

-- Bruker ALTER POLICY (bytter bare hvilken rolle policyen gjelder for) i stedet for
-- drop+create, siden det er nok til å stramme inn tilgangen og lar policyen beholde sin
-- eksisterende using/with check-logikk uendret.
do $$ begin
  alter policy "anon full access deliveries" on deliveries to authenticated;
  alter policy "anon full access deliveries" on deliveries rename to "authenticated full access deliveries";
exception when undefined_object then null; end $$;

do $$ begin
  alter policy "anon full access office_boxes" on office_boxes to authenticated;
  alter policy "anon full access office_boxes" on office_boxes rename to "authenticated full access office_boxes";
exception when undefined_object then null; end $$;

do $$ begin
  alter policy "anon full access office_box_items" on office_box_items to authenticated;
  alter policy "anon full access office_box_items" on office_box_items rename to "authenticated full access office_box_items";
exception when undefined_object then null; end $$;

do $$ begin
  alter policy "anon full access office_box_links" on office_box_links to authenticated;
  alter policy "anon full access office_box_links" on office_box_links rename to "authenticated full access office_box_links";
exception when undefined_object then null; end $$;

do $$ begin
  alter policy "anon full access office_box_contacts" on office_box_contacts to authenticated;
  alter policy "anon full access office_box_contacts" on office_box_contacts rename to "authenticated full access office_box_contacts";
exception when undefined_object then null; end $$;

do $$ begin
  alter policy "anon full access office_box_status_items" on office_box_status_items to authenticated;
  alter policy "anon full access office_box_status_items" on office_box_status_items rename to "authenticated full access office_box_status_items";
exception when undefined_object then null; end $$;
