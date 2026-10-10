import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Setter eller oppretter den delte innloggingskoden for et fag (eller "Menighet") I ET GITT
// PROSJEKT. Kalles fra Administrasjon-siden av en innlogget byggeleder - aldri direkte fra noen
// annen rolle. Service-rollen (SUPABASE_SERVICE_ROLE_KEY) er tilgjengelig som miljøvariabel
// automatisk i alle Edge Functions, og brukes HER - ALDRI i nettleserkoden - til å
// opprette/endre den delte Supabase Auth-kontoen.
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

  // 2) Sjekk at innringeren faktisk er byggeleder (service-rollen går forbi RLS, så dette MÅ
  // gjøres i funksjonen - uten denne sjekken kunne hvem som helst med en gyldig innlogging satt
  // koden for et fag).
  const { data: callerProfile, error: profileErr } = await serviceClient
    .from("profiles")
    .select("role")
    .eq("id", userRes.user.id)
    .single();
  if (profileErr || !callerProfile || callerProfile.role !== "byggeleder") {
    return jsonResponse({ error: "Kun byggeleder kan gjøre dette." }, 403);
  }

  // 3) Valider input.
  let body: { projectId?: string; fagKey?: string; code?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Ugyldig forespørsel." }, 400);
  }
  const projectId = (body.projectId || "").trim();
  const fagKey = (body.fagKey || "").trim();
  const code = (body.code || "").trim();
  if (!projectId) return jsonResponse({ error: "Mangler projectId." }, 400);
  if (!fagKey) return jsonResponse({ error: "Mangler fagKey." }, 400);
  if (code.length < 6) return jsonResponse({ error: "Koden må være minst 6 tegn." }, 400);

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
    return jsonResponse({ ok: true, created: false }, 200);
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

  return jsonResponse({ ok: true, created: true }, 200);
});
