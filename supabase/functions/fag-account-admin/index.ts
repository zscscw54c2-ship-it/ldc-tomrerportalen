import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Setter eller oppretter den delte innloggingskoden for et fag (eller "Menighet") I ET GITT
// PROSJEKT. Med { action: "deleteProject" } slettes i stedet hele prosjektet (se deleteProject).
// Kalles fra Administrasjon-siden av en innlogget CG1-admin - aldri direkte fra noen annen rolle.
// Service-rollen (SUPABASE_SERVICE_ROLE_KEY) er tilgjengelig som miljøvariabel automatisk i
// alle Edge Functions, og brukes HER - ALDRI i nettleserkoden - til å opprette/endre/slette de
// delte Supabase Auth-kontoene.
//
// Kontoen er nøkkelen (project_id, fag_key) - samme fag kan derfor ha forskjellig kode i to
// prosjekter som går samtidig. "kontakt" er et gyldig fag_key (Menighet), selv om det ikke er en
// rad i "fags" - det er en av de faste rollene profiles.role allerede godtar.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// Nettleseren sender alltid en OPTIONS-preflight før selve POST-kallet når Authorization-header
// er satt - uten disse headerne (og uten å svare på OPTIONS i det hele tatt) blokkerer
// nettleseren det virkelige kallet før det engang blir sendt.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function accountEmail(projectId: string, fagKey: string): string {
  return "acct-" + fagKey + "-" + projectId + "@fagkonto.ldc-tomrerportalen.invalid";
}

// Lagrer koden lesbart for «Vis kode» i Administrasjon (sql/84) - i en egen tabell som bare aktiv
// CG1-admin kan lese. Feiler dette, er selve koden likevel satt; vi returnerer da bare en advarsel.
// deno-lint-ignore no-explicit-any
async function rememberCode(client: any, projectId: string, fagKey: string, code: string): Promise<boolean> {
  const { error } = await client
    .from("fag_account_codes")
    .upsert({ project_id: projectId, fag_key: fagKey, code, updated_at: new Date().toISOString() }, { onConflict: "project_id,fag_key" });
  return !error;
}

const FILE_BUCKETS = ["tegninger", "dokumentasjon", "referater", "handleliste", "godsmottak"];

// Alle filstier under en mappe (prosjekt-id) i en filmappe, også i undermapper.
// deno-lint-ignore no-explicit-any
async function listAllFiles(client: any, bucket: string, prefix: string): Promise<string[]> {
  const out: string[] = [];
  for (let offset = 0; ; offset += 1000) {
    const { data, error } = await client.storage.from(bucket).list(prefix, { limit: 1000, offset });
    if (error) throw new Error(bucket + ": " + error.message);
    const items = data || [];
    for (const it of items) {
      const p = prefix + "/" + it.name;
      if (it.id === null) out.push(...await listAllFiles(client, bucket, p)); // undermappe
      else out.push(p);
    }
    if (items.length < 1000) return out;
  }
}

// P8.4: Slett et avsluttet prosjekt helt. Rekkefølgen er viktig:
//   1) Prosjektets delte fag-/menighetskontoer slettes i Auth. Ellers blir profilen stående uten
//      prosjekt (profiles.project_id settes til null), og "uten prosjekt" betyr i can_see_project()
//      en gammel konto som ser ALLE prosjekter - den gamle koden ville da gitt tilgang overalt.
//   2) Alle filer under prosjekt-mappen i filmappene slettes (også godsmottak, sql/97).
//   3) Prosjektet slettes; databasen sletter resten (personer, oppmøte, allergier ...) via
//      "on delete cascade".
// Stopper ved første feil, før prosjektet slettes, så ingenting blir liggende halvveis uten at
// admin får beskjed (et nytt forsøk fortsetter der det stoppet).
// deno-lint-ignore no-explicit-any
async function deleteProject(serviceClient: any, projectId: string, confirmName: string): Promise<Response> {
  const { data: project, error: projectErr } = await serviceClient
    .from("projects").select("id, name").eq("id", projectId).maybeSingle();
  if (projectErr || !project) return jsonResponse({ error: "Fant ikke prosjektet." }, 404);
  if ((confirmName || "").trim() !== project.name) {
    return jsonResponse({ error: "Prosjektnavnet stemmer ikke - prosjektet er ikke slettet." }, 400);
  }

  const { data: accounts, error: accErr } = await serviceClient
    .from("fag_accounts").select("auth_user_id").eq("project_id", projectId);
  const { data: lockedProfiles, error: profErr } = await serviceClient
    .from("profiles").select("id, role").eq("project_id", projectId);
  if (accErr || profErr) {
    return jsonResponse({ error: "Kunne ikke slå opp kontoene: " + (accErr || profErr).message }, 500);
  }
  const userIds = new Set<string>();
  (accounts || []).forEach((a: { auth_user_id: string }) => userIds.add(a.auth_user_id));
  // Bare delte kontoer (aldri en CG1-bruker, selv om den skulle ha prosjekt satt).
  (lockedProfiles || []).forEach((p: { id: string; role: string }) => { if (p.role !== "byggeleder") userIds.add(p.id); });
  for (const id of userIds) {
    const { error } = await serviceClient.auth.admin.deleteUser(id);
    if (error && !/not.?found/i.test(error.message)) {
      return jsonResponse({ error: "Kunne ikke slette en innloggingskonto: " + error.message + ". Prosjektet er ikke slettet." }, 500);
    }
  }

  let filesDeleted = 0;
  try {
    for (const bucket of FILE_BUCKETS) {
      const paths = await listAllFiles(serviceClient, bucket, projectId);
      for (let i = 0; i < paths.length; i += 100) {
        const { error } = await serviceClient.storage.from(bucket).remove(paths.slice(i, i + 100));
        if (error) throw new Error(bucket + ": " + error.message);
      }
      filesDeleted += paths.length;
    }
  } catch (e) {
    return jsonResponse({ error: "Kunne ikke slette filene (" + (e as Error).message + "). Kontoene er slettet, prosjektet er ikke slettet - prøv igjen." }, 500);
  }

  const { error: delErr } = await serviceClient.from("projects").delete().eq("id", projectId);
  if (delErr) {
    return jsonResponse({ error: "Kontoer og filer er slettet, men selve prosjektet kunne ikke slettes: " + delErr.message }, 500);
  }
  return jsonResponse({ ok: true, deleted: true, accountsDeleted: userIds.size, filesDeleted }, 200);
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Connection": "keep-alive" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Kun POST er støttet." }, 405);
  }

  const authHeader = req.headers.get("Authorization") || "";

  // 1) Verifiser hvem som ringer, via deres EGEN økt (anon-klient + deres Authorization-header) -
  // ikke bare at JWT-en er gyldig (det sjekker Edge Function-plattformen allerede), men hvem det
  // faktisk er.
  const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userRes, error: userErr } = await callerClient.auth.getUser();
  if (userErr || !userRes?.user) {
    return jsonResponse({ error: "Ikke innlogget." }, 401);
  }

  const serviceClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // 2) Sjekk at innringeren faktisk er byggeleder OG aktiv CG1-admin (cg1_access, sql/79).
  // Service-rollen går forbi RLS, så dette MÅ gjøres i funksjonen - uten denne sjekken kunne
  // hvem som helst med en gyldig innlogging satt koden for et fag. Admin-kravet matcher at bare
  // admin ser Administrasjon (der "Sett kode" ligger) i appen.
  const { data: callerProfile, error: profileErr } = await serviceClient
    .from("profiles")
    .select("role")
    .eq("id", userRes.user.id)
    .single();
  if (profileErr || !callerProfile || callerProfile.role !== "byggeleder") {
    return jsonResponse({ error: "Kun byggeleder kan gjøre dette." }, 403);
  }
  const { data: callerAccess } = await serviceClient
    .from("cg1_access")
    .select("is_admin, active")
    .eq("user_id", userRes.user.id)
    .maybeSingle();
  if (!callerAccess || !callerAccess.is_admin || !callerAccess.active) {
    return jsonResponse({ error: "Kun admin kan gjøre dette." }, 403);
  }

  // 3) Valider input.
  let body: { action?: string; projectId?: string; fagKey?: string; code?: string; confirmName?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Ugyldig forespørsel." }, 400);
  }
  if (body.action === "deleteProject") {
    if (!(body.projectId || "").trim()) return jsonResponse({ error: "Mangler projectId." }, 400);
    return await deleteProject(serviceClient, body.projectId!.trim(), body.confirmName || "");
  }
  const projectId = (body.projectId || "").trim();
  const fagKey = (body.fagKey || "").trim();
  const code = (body.code || "").trim();
  if (!projectId) return jsonResponse({ error: "Mangler projectId." }, 400);
  if (!fagKey) return jsonResponse({ error: "Mangler fagKey." }, 400);
  if (code.length < 8) return jsonResponse({ error: "Koden må være minst 8 tegn." }, 400);

  const { data: projectRow, error: projectErr } = await serviceClient
    .from("projects")
    .select("id")
    .eq("id", projectId)
    .maybeSingle();
  if (projectErr || !projectRow) {
    return jsonResponse({ error: "Fant ikke prosjektet." }, 404);
  }
  if (fagKey !== "kontakt") {
    const { data: fagRow, error: fagErr } = await serviceClient
      .from("fags")
      .select("key")
      .eq("key", fagKey)
      .maybeSingle();
    if (fagErr || !fagRow) {
      return jsonResponse({ error: "Fant ikke faget «" + fagKey + "»." }, 404);
    }
  }

  // 4) Opprett kontoen hvis den ikke finnes for dette prosjektet+faget, eller sett ny kode på
  // den eksisterende.
  const { data: existing, error: existingErr } = await serviceClient
    .from("fag_accounts")
    .select("auth_user_id")
    .eq("project_id", projectId)
    .eq("fag_key", fagKey)
    .maybeSingle();
  if (existingErr) {
    return jsonResponse({ error: "Kunne ikke slå opp kontoen: " + existingErr.message }, 500);
  }

  if (existing) {
    const { error: updateErr } = await serviceClient.auth.admin.updateUserById(
      existing.auth_user_id,
      { password: code },
    );
    if (updateErr) {
      return jsonResponse({ error: "Kunne ikke endre koden: " + updateErr.message }, 500);
    }
    const remembered = await rememberCode(serviceClient, projectId, fagKey, code);
    return jsonResponse({ ok: true, created: false, remembered }, 200);
  }

  const { data: created, error: createErr } = await serviceClient.auth.admin.createUser({
    email: accountEmail(projectId, fagKey),
    password: code,
    email_confirm: true,
  });
  if (createErr || !created?.user) {
    return jsonResponse({ error: "Kunne ikke opprette kontoen: " + (createErr?.message || "ukjent feil") }, 500);
  }

  const { error: profileInsertErr } = await serviceClient
    .from("profiles")
    .insert({ id: created.user.id, role: fagKey, project_id: projectId });
  if (profileInsertErr) {
    // Rydd opp i Auth-brukeren igjen hvis profilraden ikke kunne lages, så vi ikke sitter med en
    // konto uten rolle.
    await serviceClient.auth.admin.deleteUser(created.user.id);
    return jsonResponse({ error: "Kunne ikke lagre rollen for kontoen: " + profileInsertErr.message }, 500);
  }

  const { error: linkErr } = await serviceClient
    .from("fag_accounts")
    .insert({ project_id: projectId, fag_key: fagKey, auth_user_id: created.user.id });
  if (linkErr) {
    return jsonResponse({ error: "Kontoen ble opprettet, men kunne ikke kobles til prosjektet/faget: " + linkErr.message }, 500);
  }

  const remembered = await rememberCode(serviceClient, projectId, fagKey, code);
  return jsonResponse({ ok: true, created: true, remembered }, 200);
});
