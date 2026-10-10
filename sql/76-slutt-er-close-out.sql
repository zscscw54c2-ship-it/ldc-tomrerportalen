-- "Slutt" og "close out" var tidligere to separate datoer på et prosjekt, men er i praksis alltid
-- det samme - close out ER sluttdatoen. Redigeringsdialogen i appen har nå bare ett felt
-- ("Close out") i stedet for to, og lagrer samme verdi i begge kolonnene fra nå av.
--
-- Denne engangsjobben retter opp i de prosjektene som allerede hadde et avvik mellom de to
-- (ett prosjekt hadde én dags avvik) - end_date settes til close_out_date der close_out_date er
-- satt. end_date-kolonnen beholdes i databasen (mye av appen leser den for ukeberegninger osv.),
-- den er bare ikke lenger redigerbar som et eget felt.
-- Lim hele filen inn i Supabase > SQL Editor > New query, og trykk Run. Trygt å kjøre flere ganger.

update projects set end_date = close_out_date
where close_out_date is not null and end_date is distinct from close_out_date;
