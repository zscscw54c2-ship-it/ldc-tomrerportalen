# LDC-portalen – forbedringsplan

Fra gjennomgangen 11. oktober 2026. Vi tar punktene i rekkefølge. Status oppdateres her etter hvert
som punkter blir ferdige og publisert.

Merket **(DB)** = endrer databasen → forklares og venter på «ok» før noe kjøres (regel 2).

| # | Punkt | Type | Status |
|---|---|---|---|
| P1 | Hent all oppmøtedata (1000-radersgrensen) | Kode | ✅ Publisert |
| P2 | Menighetens Behov-utfylling virker ikke helt | Kode + (DB) | ✅ Publisert |
| P3 | Slett 3 ødelagte flex-forespørsler | (DB), godkjent | ✅ Ferdig (3 slettet, 6 gyldige igjen) |
| P4 | Lås delte fag-/menighetskontoer til prosjektet i databasen | (DB), stor | ✅ I drift (sql/81 kjørt 11. okt) |
| P5 | Gjør filmappene private | (DB) + kode | ✅ I drift (kode publisert, sql/82 kjørt 11. okt) |
| P6 | Raske sikkerhetsgrep | Bruker + kode + (DB) | ✅ Publisert |
| P7 | Rydd bort gamle rester | (DB) | 🔄 A: kontoer slettet, du kjører sql/85 · B: venter på bytte til fagkode |
| P8 | Forbedringer (oppsettstatus, innloggingsinfo, utskrift, arkivering, eksport, frakoblet) | Kode, noe (DB) | ✅ |
| P9 | Runde 2: flyten per rolle (fag, menighet, CG1) | Kode | ✅ Publisert (alle punkter) |

---

## P1 – Hent all oppmøtedata ✅
**Problem:** Supabase gir maks 1000 rader per spørring. `attendance` har 1648 rader (1212 i Bø), så
ca. 650 oppmøtedager manglet tilfeldig i Frivillige, Behov, Mat og Team.
**Løsning:** Ny `selectAllRows()` henter side for side (1000 om gangen, sortert på id) til alt er
med. Brukt på alle 23 tabeller som kan vokse (oppmøte, personer, oppgaver, logi, behov, tegninger,
dokumentasjon, handleliste, flex, TO-møte osv.).

## P2 – Menighetens Behov-utfylling ✅
**Problem:** Når menigheten fyller inn et navn under «Behov for hjelp», lagres navnet, men
- oppmøtet registreres ikke (tilgangsreglene lar bare faget/byggeleder skrive oppmøte), og
- «Eller skriv et nytt navn» feiler helt (menigheten får ikke legge til personer).

**Gjort:** `sql/80-fill-behov-day.sql` er kjørt, og appen bruker funksjonen. Testet i databasen
(i transaksjoner som ble rullet tilbake): ny person, dag satt, oppmøte og oppgave OK; menighet fra
annet prosjekt og person fra annet prosjekt avvises; ingen dobbel oppføring.

**Plan (opprinnelig):**
1. (DB) Ny funksjon `fill_behov_day(day_id, person_id | new_name)` (security definer) som gjør hele
   utfyllingen på vegne av menigheten: setter navnet, legger til ny person om nødvendig,
   registrerer oppmøte og oppretter oppgave for «andre behov» – men bare for prosjektet kontoen er
   låst til, og bare på dager som faktisk er markert som behov.
2. Kode: menighetsvisningen kaller funksjonen i stedet for å skrive direkte.
3. Test med Playwright; ingen endring for byggeleder.

## P3 – Slett 3 ødelagte flex-forespørsler ✅
Slettet 11. okt. (Vanlige skrive-spørringer tidsavbrøt fra verktøyet; det virket inne i en
`do $$ … $$`-blokk.)

## P4 – Lås delte kontoer til prosjektet i databasen ✅
**Gjort (11. okt):** `sql/81-prosjektlas.sql` – funksjonen `can_see_project()` + én restriktiv regel
«p4 prosjektlås» på 43 tabeller (eksisterende regler urørt). Angre: `sql/81-angre-prosjektlas.sql`.

Kontrollert mot ekte data (som hver rolle, i lesemodus):
| | prosjekter | personer | oppmøte |
|---|---|---|---|
| CGO (byggeleder) | 2 | 217 | 1648 (uendret) |
| Tømrer Bø | 1 | 177 | 1212 (før: 2 / 217 / 1648) |
| Tømrer Kalmar | 1 | 40 | 436 (før: 2 / 217 / 1648) |
| Menighet (Kalmar) | 1 | 40 | 436 (før: 2 / 217 / 1648) |
| Gammel individuell fag-konto | 2 | 217 | 1648 (uendret til P7) |
| Ikke innlogget | – | – | oppgaver: 0 (før: kunne leses!) |

Skriving testet: tømrer Bø kan registrere oppmøte i Bø, avvises i Kalmar.

### Opprinnelig plan
**Problem:** Låsen til ett prosjekt finnes bare i skjermbildet. I databasen kan alle innloggede
lese alle 217 personer (telefon, adresse) på tvers av prosjekter; menigheten også allergier.
**Plan:**
1. (DB) Hjelpefunksjon `can_see_project(project_id)`: byggeleder → alle; delt fag-/menighetskonto →
   bare `profiles.project_id`; gamle individuelle kontoer → som før til de er ryddet bort (P7).
2. (DB) Oppdater lese-/skriveregler tabell for tabell (personer, oppmøte, logi, behov, oppgaver,
   handleliste, tegninger, dokumentasjon, flex, team, TO-møte …) til å bruke den.
3. Test hver rolle (byggeleder, fag, menighet) mot ekte data i lesemodus før og etter.
4. Kjøres i én migrering, med en ferdig «angre»-fil klar.

## P5 – Private filmapper
**Trinn 1 (kode) ✅:** appen bruker tidsbegrensede (signerte) lenker, hentet samlet per mappe og
husket i en time. Virker både med åpne og private mapper → trygt å publisere først.
**Trinn 2 (DB) ✅ kjørt 11. okt:** `sql/82-private-filmapper.sql` – alle fire mappene er private,
og filer har samme prosjektlås som P4. Kontrollert: CGO når alle 65 filer, tømrer Bø bare Bø-filene
(42 tegninger, 11 bilder, 2 referater), tømrer/menighet Kalmar bare Kalmar-filene (10 tegninger).

### Opprinnelig beskrivelse
**Problem:** Tegninger, dokumentasjonsbilder, referater og handlelistebilder (65 filer, 70 MB) ligger
i offentlige mapper – alle med lenken kan åpne dem.
**Plan:** (DB) Gjør mappene private med lesetilgang kun for innloggede (og per prosjekt etter P4);
kode: bruk signerte lenker (tidsbegrensede) i stedet for offentlige.

## P6 – Raske sikkerhetsgrep
1. ~~**Du:** Supabase → Authentication → «Leaked password protection» → slå på.~~ **Hoppet over:**
   krever Pro-abonnement (Rene Hus AS er på gratisplanen). Kompenseres med punkt 2.
2. ✅ Kode: ny kodedialog (fag + Menighet) med minst 8 tegn og «Lag sterk kode» (ord-tall-ord,
   f.eks. «bjork-47-stige»). fag-account-admin håndhever 8 tegn på serveren.
3. ✅ (DB) `user_accounts`-visningen: appen leser rolle/person rett fra `profiles`. Tilgangen til
   visningen er fjernet for alle (sql/83); selve slettingen hang fra verktøyet og tas i P7.
4. ✅ «Vis kode» for fag-/menighetskoder: fag-account-admin (v5, krever 8 tegn) lagrer koden i
   `fag_account_codes` (sql/84), som bare aktiv CG1-admin kan lese. Koder satt før dette vises som
   «Ukjent – sett ny kode». CG1-passord lagres aldri.

## P7 – Rydd bort gamle rester
**A – gjort 11. okt:** 6 ubrukte/erstattede kontoer slettet (landscape, maler, murer, ventilasjon,
vvs @cg1.org + gammel delt menighetskonto). search_path satt på to funksjoner. Invitasjonsflyten
fjernet fra appen. **Gjenstår:** `sql/85-opprydding.sql` (alle «drop»-setningene – de henger fra
verktøyet, så de kjøres i Supabase SQL Editor).

**B – aktive gamle kontoer:** `elektriker@cg1.org`, `tomrer@cg1.org` og en tømrer-konto (icloud)
skal bytte til fagkode. Når de har byttet, slettes kontoene (Administrasjon har ikke disse – det
gjøres i databasen). Elektriker mangler fagkode i begge prosjekter.

### Opprinnelig liste
- 7 gamle individuelle fag-kontoer (elektriker, landscape, maler, murer, tømrer ×2, ventilasjon, vvs)
- gammel delt menighetskonto (`@cg1.org`)
- `projects.access_code` + funksjonen `verify_project_code`
- `project_invites` (2 rader) + invitasjonsflyten i appen
- testtabellen `fag_trigger_test`
- visningen `user_accounts` (tilgang allerede fjernet i P6)
- `search_path` på `check_profile_role` / `check_fag_column`

Hver sletting listes opp med konsekvens før «ok».

## P8 – Forbedringer
1. ✅ **Oppsettstatus for prosjekt** i Administrasjon: hva mangler (koder, menighetskode, team,
   privilege-uker, datoer).
2. ✅ **«Kopier innloggingsinfo»** når en kode settes: ferdig melding med lenke + prosjekt + fag + kode.
3. ✅ **Utskrift (PDF):** «Utskrifter» i Administrasjon – oppmøteliste for en dag (med Inn/Ut-
   kolonner), matliste for uken (antall + allergier per dag), telefonliste (teamet først).
   Menighetens Mat-side har «Skriv ut matliste for uken».
4. ✅ **Slett avsluttet prosjekt** (planen er at prosjektet slettes helt etter close out):
   «Slett prosjekt» skjer nå på serveren (fag-account-admin v6, action «deleteProject», bare aktiv
   CG1-admin): prosjektets fag-/menighetskontoer slettes i Auth (ellers ville de blitt stående uten
   prosjekt og sett ALLE prosjekter), alle filer i de fire filmappene slettes, og så prosjektet –
   databasen sletter resten (personer, oppmøte, allergier …) via cascade. Dialogen viser hva som
   slettes, har «Eksporter først», og krever at prosjektnavnet skrives (sjekkes også på serveren).
   Oppsettkortet minner om eksport og sletting når close out er passert. Ingen tabellendring.
5. ✅ **Eksporter prosjekt (Excel)** før sletting / som sikkerhetskopi: «Utskrifter og eksport» i
   Administrasjon. Henter rett fra databasen, ett ark per tabell (alle kolonner) + arket «Oversikt»
   med antall rader og eventuelle tabeller som ikke kunne hentes. Innloggingskoder, kontoer og
   CG1-tavlene er ikke med.
6. ✅ **Frakoblet-varsel** og automatisk nytt forsøk ved dårlig dekning: gult banner når telefonen
   er uten nett; data hentes på nytt når nettet er tilbake og når siden har ligget i bakgrunnen
   over ett minutt. Lesing prøves inntil 4 ganger; lagring sendes aldri dobbelt, men venter (inntil
   2 min) hvis telefonen vet at den er frakoblet. «Failed to fetch» vises som en norsk melding.

## P9 – Runde 2: flyten per rolle ✅
**Gjort (alle punkter, 11. okt):** dagrad (Ma 5, Ti 6 …, i dag uthevet) i Behov/Frivillige/Logi;
Behov åpner på denne uken (også for CG1) og menigheten ser bare fag med plasser; kalenderen på mobil
scroller over navnelistene – kort trykk velger, hold inne (350 ms) for å dra, ny hjelpetekst;
kortnavn bruker fullt etternavn når forbokstaven kolliderer, og navnespalten er bredere på mobil;
Oppgaver åpner på «Ikke ferdig»; søk i Tegninger (fra 8 filer); prosjektnavnet vises som tekst når
det bare er ett prosjekt; Team-flisen viser ukens ansvarlige; «Legg til under Team»; «N satt opp» i
kalenderen; «Mangler» får plass i smale celler. Punkt 10 (rollenavn) var en feil i testdataene –
ekte CG1-brukere har visningsnavn; bare reserveløsningen er rettet (første CG1-side i stedet for «ACGO»).

Gjennomgått 11. okt med skjermbilder på mobil (390 px) og PC for tømrer, elektriker, menighet, CGO og
ACGO, med syntetiske data i samme volum som Bø (177 personer, ~1200 oppmøtedager, 72 oppgaver).
Alt er ren kode – ingen databaseendring.

**Fag (tømrer, elektriker) – mest på mobil**
1. **Kalender: siden lar seg ikke scrolle over «Ledige»-listen.** Navnelappene er satt til
   `touch-action: none` (for dra-og-slipp) og dekker hele bredden – med 20–30 ledige blir et stort
   felt «dødt» for scrolling. Trykk-for-å-velge finnes allerede, så dra kan kreve langt trykk.
   Hjelpeteksten sier bare «Dra navnet opp på en oppgave» – bør si «Trykk på et navn, så på oppgaven».
2. **Frivillige-/Logi-rutenettet mangler dagrad.** Overskriften viser måned og uke, men ikke «Ma 5,
   Ti 6 …». Rett under står «Totalt»-tallene (9, 10, 11 …) i fet blå skrift – de ser ut som datoer.
   Gjelder fag, menighet (Logi) og CG1.
3. **Logi på mobil: navn kuttes** («Anne…» fire ganger) – umulig å skille personer.
4. **Oppgaver åpner på «Alle»** – 44 kort, 30 av dem ferdige. Bør åpne på «Ikke ferdig» (eller
   legge ferdige sammenfoldet nederst).
5. **Tegninger: ingen søk.** 21–42 filer med revisjoner i én lang liste.
6. **Prosjektknappen «Bø ★» ser klikkbar ut** for kontoer som er låst til prosjektet.
7. **Hjem-flisen «Team – 0 ansvarspunkter»** for fag – uklart hva den er for.

**Menighet**
8. **Behov åpner på prosjektstart** (uke 36), ikke denne uken – på mobil må man sveipe 5–6 uker
   til siden for å finne dagene som er markert. Fag uten plasser vises også (tomme rader).
9. Mat-siden fungerer godt (antall + allergier per dag, utskrift).

**CG1 (CGO/ACGO/Kontor)**
10. **Rollenavnet øverst viser «ACGO» for alle CG1-brukere**, også CGO og Kontor.
11. **Dashbord: «Legg til under Åndelig»** – fanen heter nå «Team».
12. **Kalender: «3 pers.» i dagoverskriften vs. «25 til stede»** – uklart. «3 satt opp» er tydeligere.

**Bruk i ekte data (Bø)** – funksjoner som nesten ikke brukes: Behov-for-hjelp (0 dager markert,
noensinne), Leveranser (0), Logi (6 av 177 personer), To-do (3). Spørsmål: skal de forenkles,
skjules, eller trengs det opplæring/en tydeligere vei inn?

## Flex for fag-innlogginger ✅
Administrasjon → Fag → **«Flex for»** (vises når faget har kode): kobler fag-innloggingen i prosjektet
til et par i teamet (samme felt som CG1-brukernes personkobling, `profiles.person_id` på fag-kontoen –
ingen tabellendring). Da slipper kontoen «Velg hvem du er», flex legges på riktig par, og Team-siden
slås på for faget automatisk. «– ingen» gir den gamle velgeren tilbake. CG1-brukere koblet til en
person i et annet prosjekt finner samme person i teamet (navn, ellers entydig etternavn).
Fag-forespørsler viser «(Menighet)»/fagnavn i stedet for den tekniske e-posten.

## Team og Flex på ett sted (sql/86)
Administrasjon → Team → **«Innlogginger i teamet»**: hver innlogging (CGO, ACGO, Kontor 1/2 og
prosjektets fag-koder) kobles til en person i teamet, per prosjekt (tabellen `team_logins`).
Regel: den som er koblet til en person i teamet, ser Team-siden og har Flex – også fag. Erstatter
«Vis Team-siden» og «Flex for» per fag og personvelgeren under Brukere og tilganger
(`profiles.person_id` og `andelig_visibility` brukes ikke lenger av appen). Ingen navnegjetting.
