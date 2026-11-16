// v395 (يبني على v392): رفع «صحيفة الأحوال الإلكترونية للمعلم» من بوابة المعلمين (بلا حساب دخول).
// verify_jwt=false: المعلم مجهول؛ التحقق بالرقم القومي والهاتف داخل service_statement_prepare (tp_check بقفل المحاولات)
// ثم مرحلة مدرسته الأصلية ومفتاح الرفع. الملف jpeg أو pdf فقط (بالبايتات لا بنوع المتصفح)، حتى 1.5 MB، ملف واحد لكل معلم يُستبدل.
// جديد v395: اسم الملف فريد لكل رفع (statement_<وقت>_<عشوائي>) حتى لا يلتبس ملف جديد بملف سبق تنزيله/نقله إلى السلة (سجل الأرشفة مفتاحه المسار)؛
// ويُعلَّم سجل الأرشفة للملف المستبدَل «removed» إن كان «downloaded».
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const MAX_BYTES = 1_500_000;
const BUCKET = "teacher-statements";
function json(d: unknown, status = 200) {
  return new Response(JSON.stringify(d), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, reason: "method" }, 405);
  let civil = "", phone = "", bytes: Uint8Array;
  if ((req.headers.get("content-type") || "").includes("application/json")) {
    // مسار JSON (base64) للاختبارات الآلية؛ البوابة ترسل multipart
    try {
      const b = await req.json();
      civil = String(b.civil || ""); phone = String(b.phone || "");
      bytes = Uint8Array.from(atob(String(b.file_b64 || "")), (c) => c.charCodeAt(0));
    } catch { return json({ ok: false, reason: "invalid" }, 400); }
  } else {
    let form: FormData;
    try { form = await req.formData(); } catch { return json({ ok: false, reason: "invalid" }, 400); }
    civil = String(form.get("civil") || "");
    phone = String(form.get("phone") || "");
    const file = form.get("file");
    if (!(file instanceof File)) return json({ ok: false, reason: "no_file" }, 400);
    bytes = new Uint8Array(await file.arrayBuffer());
  }
  if (bytes.length < 100 || bytes.length > MAX_BYTES) return json({ ok: false, reason: "too_big" }, 413);
  let mime = "", ext = "";
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) { mime = "image/jpeg"; ext = "jpg"; }
  else if (bytes[0] === 0x25 && bytes[1] === 0x50 && bytes[2] === 0x44 && bytes[3] === 0x46) { mime = "application/pdf"; ext = "pdf"; }
  else return json({ ok: false, reason: "bad_type" }, 415);

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const { data: prep, error: pe } = await admin.rpc("service_statement_prepare", { p_civil: civil, p_phone: phone });
  if (pe) return json({ ok: false, reason: "server" }, 500);
  if (!prep || prep.ok !== true) return json({ ok: false, ...(prep || { reason: "server" }) });

  const ts = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 14);
  const rnd = Array.from(crypto.getRandomValues(new Uint8Array(3))).map((b) => b.toString(16).padStart(2, "0")).join("");
  const path = `${prep.teacher_id}/statement_${ts}_${rnd}.${ext}`;
  const up = await admin.storage.from(BUCKET).upload(path, bytes, { contentType: mime });
  if (up.error) return json({ ok: false, reason: "storage" }, 500);
  if (prep.old_path && prep.old_path !== path) {
    await admin.storage.from(BUCKET).remove([prep.old_path]);
    await admin.from("file_archive_log").update({ state: "removed", removed_at: new Date().toISOString() }).eq("bucket_id", BUCKET).eq("path", prep.old_path).eq("state", "downloaded");
  }
  const { error: re } = await admin.rpc("service_statement_record", { p_teacher: prep.teacher_id, p_path: path, p_mime: mime, p_size: bytes.length });
  if (re) return json({ ok: false, reason: "server" }, 500);
  return json({ ok: true, mime, size: bytes.length });
});
