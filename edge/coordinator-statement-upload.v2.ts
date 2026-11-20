// v426: يقبل أيضًا دور مدير النظام (x-app-role=admin) بلا قيد مفتاح الرفع. v397: رفع «صحيفة الأحوال الإلكترونية» لمعلم بدل المعلم، بواسطة منسق المرحلة (من شاشة «صحائف الأحوال» في البرنامج).
// verify_jwt=true + تحقق ذاتي: JWT المستخدم، والدور النشط x-app-role=stage_coordinator، ثم service_statement_coord_prepare
// (دور المنسق نشط، إجراء statements.upload غير ممنوع من مركز التحكم، المعلم ثابت ونشط ومدرسته الأصلية في مراحل المنسق، مفتاح رفع مرحلته مفتوح، حد 10 رفعات).
// الملف jpeg أو pdf فقط (بالبايتات) حتى 1.5 MB؛ اسم الملف فريد لكل رفع (statement_<وقت>_<عشوائي>) كما في رفع المعلم؛ المنسق لا يحذف ولا يفرّغ.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-app-role" };
const MAX_BYTES = 1_500_000;
const BUCKET = "teacher-statements";
function json(d: unknown, status = 200) { return new Response(JSON.stringify(d), { status, headers: { ...cors, "Content-Type": "application/json" } }); }

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, reason: "method" }, 405);
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ ok: false, reason: "unauthorized" }, 401);
  const { data: ud, error: ue } = await admin.auth.getUser(token);
  if (ue || !ud.user) return json({ ok: false, reason: "unauthorized" }, 401);
  const uid = ud.user.id;
  const role = (req.headers.get("x-app-role") || "").trim();
  if (role !== "stage_coordinator" && role !== "admin") return json({ ok: false, reason: "role" }, 403);
  const isAdmin = role === "admin";

  let form: FormData;
  try { form = await req.formData(); } catch { return json({ ok: false, reason: "invalid" }, 400); }
  const teacherId = String(form.get("teacher_id") || "");
  const file = form.get("file");
  if (!/^[0-9a-f-]{36}$/i.test(teacherId)) return json({ ok: false, reason: "invalid" }, 400);
  if (!(file instanceof File)) return json({ ok: false, reason: "no_file" }, 400);
  const bytes = new Uint8Array(await file.arrayBuffer());
  if (bytes.length < 100 || bytes.length > MAX_BYTES) return json({ ok: false, reason: "too_big" }, 413);
  let mime = "", ext = "";
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) { mime = "image/jpeg"; ext = "jpg"; }
  else if (bytes[0] === 0x25 && bytes[1] === 0x50 && bytes[2] === 0x44 && bytes[3] === 0x46) { mime = "application/pdf"; ext = "pdf"; }
  else return json({ ok: false, reason: "bad_type" }, 415);

  const { data: prep, error: pe } = await admin.rpc(isAdmin ? "service_statement_admin_prepare" : "service_statement_coord_prepare", { p_actor: uid, p_teacher: teacherId });
  if (pe) return json({ ok: false, reason: "server" }, 500);
  if (!prep || prep.ok !== true) return json({ ok: false, reason: (prep && prep.reason) || "server" });

  const ts = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 14);
  const rnd = Array.from(crypto.getRandomValues(new Uint8Array(3))).map((b) => b.toString(16).padStart(2, "0")).join("");
  const path = `${prep.teacher_id}/statement_${ts}_${rnd}.${ext}`;
  const up = await admin.storage.from(BUCKET).upload(path, bytes, { contentType: mime });
  if (up.error) return json({ ok: false, reason: "storage" }, 500);
  if (prep.old_path && prep.old_path !== path) {
    await admin.storage.from(BUCKET).remove([prep.old_path]);
    await admin.from("file_archive_log").update({ state: "removed", removed_at: new Date().toISOString() }).eq("bucket_id", BUCKET).eq("path", prep.old_path).eq("state", "downloaded");
  }
  const { error: re } = await admin.rpc(isAdmin ? "service_statement_admin_record" : "service_statement_coord_record", { p_actor: uid, p_teacher: prep.teacher_id, p_path: path, p_mime: mime, p_size: bytes.length });
  if (re) return json({ ok: false, reason: "server" }, 500);
  return json({ ok: true, mime, size: bytes.length, path });
});
