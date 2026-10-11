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
| P5 | Gjør filmappene private | (DB) + kode | ⏳ Neste |
| P6 | Raske sikkerhetsgrep | Bruker + kode + (DB) | ⏳ |
| P7 | Rydd bort gamle rester | (DB) | ⏳ |
| P8 | Forbedringer (oppsettstatus, innloggingsinfo, utskrift, arkivering, eksport, frakoblet) | Kode, noe (DB) | ⏳ |

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
**Problem:** Tegninger, dokumentasjonsbilder, referater og handlelistebilder (65 filer, 70 MB) ligger
i offentlige mapper – alle med lenken kan åpne dem.
**Plan:** (DB) Gjør mappene private med lesetilgang kun for innloggede (og per prosjekt etter P4);
kode: bruk signerte lenker (tidsbegrensede) i stedet for offentlige.

## P6 – Raske sikkerhetsgrep
1. **Du:** Supabase → Authentication → «Leaked password protection» → slå på.
2. Kode: krev minst 8 tegn på fag-/menighetskoder (i dag 6), og vis et forslag til sterk kode.
3. (DB) Erstatt `user_accounts`-visningen (flagget av Supabase) med en sikker funksjon.

## P7 – Rydd bort gamle rester (DB)
- 7 gamle individuelle fag-kontoer (elektriker, landscape, maler, murer, tømrer ×2, ventilasjon, vvs)
- gammel delt menighetskonto (`@cg1.org`)
- `projects.access_code` + funksjonen `verify_project_code`
- `project_invites` (2 rader) + invitasjonsflyten i appen
- testtabellen `fag_trigger_test`
- `search_path` på `check_profile_role` / `check_fag_column`

Hver sletting listes opp med konsekvens før «ok».

## P8 – Forbedringer
1. **Oppsettstatus for prosjekt** i Administrasjon: hva mangler (koder, menighetskode, team,
   privilege-uker, datoer).
2. **«Kopier innloggingsinfo»** når en kode settes: ferdig melding med lenke + prosjekt + fag + kode.
3. **Utskrift/eksport:** Mat-liste per dag (antall + allergier), oppmøteliste per dag (inn/ut-
   sjekk), telefonliste.
4. **Arkiver avsluttet prosjekt:** slett/anonymiser persondata (særlig allergier) etter X måneder. (DB)
5. **Eksporter prosjekt (Excel)** før sletting / som sikkerhetskopi.
6. **Frakoblet-varsel** og automatisk nytt forsøk ved dårlig dekning.
