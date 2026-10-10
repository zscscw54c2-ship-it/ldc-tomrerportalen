import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Brukere og tilganger for CG1 (CGO, ACGO, Kontor 1, Kontor 2) - kalles fra Administrasjon-siden.
// Bare en aktiv CG1-admin (cg1_access.is_admin, se sql/79) kan bruke den. Service-rollen
// (SUPABASE_SERVICE_ROLE_KEY) brukes HER - ALDRI i nettleserkoden - til å opprette kontoer, sette
// passord og stenge/åpne kontoer i Supabase Auth.
//
// Alle CG1-brukere får rollen "byggeleder" i profiles, så eksisterende tilgangsregler (RLS) virker
// som før. cg1_access styrer i tillegg hvilke CG1-sider de ser og om de er admin. Funksjonen rører
// bare kontoer som har en rad i cg1_access - aldri fag- eller menighetskontoer.
//
// Handlinger (body.action):
//   list                                         -> alle CG1-brukere med e-post og sist innlogget
//   create      { email, password, displayName, pages, isAdmin }
//   update      { userId, displayName?, pages?, isAdmin? }
//   setPassword { userId, password }
//   setActive   { userId, active }
//   delete      { userId }                       -> sletter kontoen helt (Auth + profil + tilganger)

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const PAGES = ["cgo", "acgo", "kontor1", "kontor2"];
const BAN_FOREVER = "876000h"; // ~100 år - Supabase Auth har ingen egen "deaktivert"-status

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Connection": "keep-alive" },
  });
}

function cleanPages(input: unknown): string[] | null {
  if (!Array.isArray(input)) return null;
  const out = PAGES.filter((p) => input.indexOf(p) !== -1);
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Kun POST er støttet." }, 405);
  }

  // 1) Hvem ringer? Verifiseres via deres EGEN økt.
  const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: req.headers.get("Authorization") || "" } },
  });
  const { data: userRes, error: userErr } = await callerClient.auth.getUser();
  if (userErr || !userRes?.user) {
    return jsonResponse({ error: "Ikke innlogget." }, 401);
  }
  const callerId = userRes.user.id;

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // 2) Må være aktiv CG1-admin (service-rollen går forbi RLS, så sjekken MÅ gjøres her).
  const { data: callerAccess } = await admin
    .from("cg1_access")
    .select("is_admin, active")
    .eq("user_id", callerId)
    .maybeSingle();
  if (!callerAccess || !callerAccess.is_admin || !callerAccess.active) {
    return jsonResponse({ error: "Kun admin kan administrere brukere." }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Ugyldig forespørsel." }, 400);
  }
  const action = String(body.action || "");

  // Minst én aktiv admin må alltid finnes igjen, ellers kan ingen styre tilgangene lenger.
  async function otherActiveAdmins(exceptUserId: string): Promise<number> {
    const { count } = await admin
      .from("cg1_access")
      .select("user_id", { count: "exact", head: true })
      .eq("is_admin", true)
      .eq("active", true)
      .neq("user_id", exceptUserId);
    return count || 0;
  }
  async function loadTarget(userId: string) {
    const { data } = await admin.from("cg1_access").select("*").eq("user_id", userId).maybeSingle();
    return data;
  }

  if (action === "list") {
    const { data: rows, error } = await admin.from("cg1_access").select("*").order("created_at").order("user_id");
    if (error) return jsonResponse({ error: "Kunne ikke hente brukere: " + error.message }, 500);
    const users = [];
    for (const r of rows || []) {
      const { data: u } = await admin.auth.admin.getUserById(r.user_id);
      users.push({
        userId: r.user_id,
        email: u?.user?.email || "",
        lastSignInAt: u?.user?.last_sign_in_at || null,
        displayName: r.display_name || "",
        pages: r.pages || [],
        isAdmin: !!r.is_admin,
        active: !!r.active,
      });
    }
    return jsonResponse({ ok: true, users }, 200);
  }

  if (action === "create") {
    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");
    const displayName = String(body.displayName || "").trim().slice(0, 60) || null;
    const pages = cleanPages(body.pages) || [];
    const isAdmin = !!body.isAdmin;
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return jsonResponse({ error: "Ugyldig e-postadresse." }, 400);
    if (password.length < 8) return jsonResponse({ error: "Passordet må være minst 8 tegn." }, 400);

    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });
    if (createErr || !created?.user) {
      const msg = createErr?.message || "ukjent feil";
      return jsonResponse({ error: msg.indexOf("already") !== -1 ? "Det finnes allerede en konto med denne e-postadressen." : "Kunne ikke opprette kontoen: " + msg }, 400);
    }
    const newId = created.user.id;
    const { error: profErr } = await admin.from("profiles").insert({ id: newId, role: "byggeleder" });
    if (profErr) {
      await admin.auth.admin.deleteUser(newId);
      return jsonResponse({ error: "Kunne ikke lagre rollen: " + profErr.message }, 500);
    }
    const { error: accErr } = await admin.from("cg1_access").insert({
      user_id: newId, display_name: displayName, pages, is_admin: isAdmin,
    });
    if (accErr) {
      await admin.from("profiles").delete().eq("id", newId);
      await admin.auth.admin.deleteUser(newId);
      return jsonResponse({ error: "Kunne ikke lagre tilgangene: " + accErr.message }, 500);
    }
    return jsonResponse({ ok: true, userId: newId }, 200);
  }

  const userId = String(body.userId || "");
  if (!userId) return jsonResponse({ error: "Mangler userId." }, 400);
  const target = await loadTarget(userId);
  if (!target) return jsonResponse({ error: "Fant ikke brukeren blant CG1-brukerne." }, 404);

  if (action === "update") {
    const patch: Record<string, unknown> = { updated_at: new Date().toISOString() };
    if ("displayName" in body) patch.display_name = String(body.displayName || "").trim().slice(0, 60) || null;
    if ("pages" in body) {
      const pages = cleanPages(body.pages);
      if (!pages) return jsonResponse({ error: "Ugyldige sider." }, 400);
      patch.pages = pages;
    }
    if ("isAdmin" in body) {
      const isAdmin = !!body.isAdmin;
      if (!isAdmin && target.is_admin && target.active && (await otherActiveAdmins(userId)) === 0) {
        return jsonResponse({ error: "Det må alltid være minst én aktiv admin." }, 400);
      }
      patch.is_admin = isAdmin;
    }
    const { error } = await admin.from("cg1_access").update(patch).eq("user_id", userId);
    if (error) return jsonResponse({ error: "Kunne ikke lagre: " + error.message }, 500);
    return jsonResponse({ ok: true }, 200);
  }

  if (action === "setPassword") {
    const password = String(body.password || "");
    if (password.length < 8) return jsonResponse({ error: "Passordet må være minst 8 tegn." }, 400);
    const { error } = await admin.auth.admin.updateUserById(userId, { password });
    if (error) return jsonResponse({ error: "Kunne ikke sette passord: " + error.message }, 500);
    return jsonResponse({ ok: true }, 200);
  }

  if (action === "setActive") {
    const active = !!body.active;
    if (!active) {
      if (userId === callerId) return jsonResponse({ error: "Du kan ikke deaktivere deg selv." }, 400);
      if (target.is_admin && target.active && (await otherActiveAdmins(userId)) === 0) {
        return jsonResponse({ error: "Det må alltid være minst én aktiv admin." }, 400);
      }
    }
    const { error: banErr } = await admin.auth.admin.updateUserById(userId, { ban_duration: active ? "none" : BAN_FOREVER });
    if (banErr) return jsonResponse({ error: "Kunne ikke endre kontoen: " + banErr.message }, 500);
    const { error } = await admin.from("cg1_access").update({ active, updated_at: new Date().toISOString() }).eq("user_id", userId);
    if (error) return jsonResponse({ error: "Kunne ikke lagre: " + error.message }, 500);
    return jsonResponse({ ok: true }, 200);
  }

  if (action === "delete") {
    if (userId === callerId) return jsonResponse({ error: "Du kan ikke slette deg selv." }, 400);
    if (target.is_admin && target.active && (await otherActiveAdmins(userId)) === 0) {
      return jsonResponse({ error: "Det må alltid være minst én aktiv admin." }, 400);
    }
    // project_invites.used_by peker på Auth-brukeren uten "on delete" - nullstill først, ellers
    // stopper fremmednøkkelen slettingen. profiles og cg1_access slettes automatisk (cascade).
    const { error: invErr } = await admin.from("project_invites").update({ used_by: null }).eq("used_by", userId);
    if (invErr) return jsonResponse({ error: "Kunne ikke rydde invitasjoner: " + invErr.message }, 500);
    const { error: delErr } = await admin.auth.admin.deleteUser(userId);
    if (delErr) return jsonResponse({ error: "Kunne ikke slette kontoen: " + delErr.message }, 500);
    return jsonResponse({ ok: true }, 200);
  }

  return jsonResponse({ error: "Ukjent handling." }, 400);
});
