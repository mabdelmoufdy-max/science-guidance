// v393: أرشفة ملفات التخزين لمدير النظام: نقل إلى سلة مؤقتة (_trash/) ← استرجاع ← إزالة نهائية.
// لا يعمل إلا على ملفات سبق تنزيلها (file_archive_log.state='downloaded') وبحجمها المسجَّل، والإزالة النهائية لما في السلة فقط.
// التحقق: JWT المستخدم + الدور النشط admin (x-app-role) + دور admin فعّال + (لملفات الأجر) وجوده في paid_teacher_viewers.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-app-role" };
const BUCKETS = new Set(["paid-teacher-docs", "teacher-statements"]);
function json(d: unknown, status = 200) { return new Response(JSON.stringify(d), { status, headers: { ...cors, "Content-Type": "application/json" } }); }
async function pool<T>(items: T[], n: number, fn: (x: T) => Promise<void>) {
  let i = 0;
  await Promise.all(Array.from({ length: Math.min(n, items.length) }, async () => { while (i < items.length) { const x = items[i++]; await fn(x); } }));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ ok: false, error: "Unauthorized" }, 401);
  const { data: ud, error: ue } = await admin.auth.getUser(token);
  if (ue || !ud.user) return json({ ok: false, error: "Unauthorized" }, 401);
  const uid = ud.user.id;
  const { data: prof } = await admin.from("profiles").select("id,is_active").eq("id", uid).single();
  if (!prof?.is_active) return json({ ok: false, error: "الحساب غير مفعل" }, 403);
  if ((req.headers.get("x-app-role") || "").trim() !== "admin") return json({ ok: false, error: "هذه العملية لمدير النظام (الدور النشط admin) فقط" }, 403);
  const { data: ur } = await admin.from("user_roles").select("role").eq("profile_id", uid).eq("role", "admin").eq("is_active", true).maybeSingle();
  if (!ur) return json({ ok: false, error: "الدور النشط غير مسموح لهذا الحساب" }, 403);

  let body: { action?: string; bucket?: string };
  try { body = await req.json(); } catch { return json({ ok: false, error: "طلب غير صالح" }, 400); }
  const action = String(body.action || ""), bucket = String(body.bucket || "");
  if (!BUCKETS.has(bucket)) return json({ ok: false, error: "حاوية غير مسموحة" }, 400);
  if (bucket === "paid-teacher-docs") {
    const { data: v } = await admin.from("paid_teacher_viewers").select("user_id").eq("user_id", uid).maybeSingle();
    if (!v) return json({ ok: false, error: "لست ضمن من يحق لهم عرض ملفات طلبات الأجر" }, 403);
  }
  const st = admin.storage.from(bucket);
  const stamp = new Date().toISOString().slice(0, 10).replaceAll("-", "");
  const audit = (act: string, data: unknown) => admin.from("audit_log").insert({ actor_profile_id: uid, actor_role: "admin", action: act, entity_type: "storage_files", entity_id: bucket, new_data: data });

  if (action === "quarantine") {
    const { data: rows, error } = await admin.from("file_archive_log").select("path,size").eq("bucket_id", bucket).eq("state", "downloaded");
    if (error) return json({ ok: false, error: error.message }, 500);
    const list = rows || [];
    if (!list.length) return json({ ok: true, moved: 0, skipped_changed: [], skipped_missing: [], failed: [] });
    const { data: cur, error: ce } = await admin.rpc("service_files_current", { p_bucket: bucket, p_paths: list.map((r) => r.path) });
    if (ce) return json({ ok: false, error: ce.message }, 500);
    const have = new Map<string, number>((cur || []).map((c: { path: string; size: number }) => [c.path, Number(c.size)]));
    const skippedMissing: string[] = [], skippedChanged: string[] = [], failed: { path: string; error: string }[] = [];
    const todo = list.filter((r) => {
      if (!have.has(r.path)) { skippedMissing.push(r.path); return false; }
      if (have.get(r.path) !== Number(r.size)) { skippedChanged.push(r.path); return false; }
      return true;
    });
    let moved = 0;
    await pool(todo, 6, async (r) => {
      const tp = `_trash/${stamp}/${r.path}`;
      const m = await st.move(r.path, tp);
      if (m.error) { failed.push({ path: r.path, error: m.error.message }); return; }
      const u = await admin.from("file_archive_log").update({ state: "quarantined", trash_path: tp, quarantined_at: new Date().toISOString() }).eq("bucket_id", bucket).eq("path", r.path);
      if (u.error) { failed.push({ path: r.path, error: "نُقل الملف لكن تعذر تسجيله: " + u.error.message }); return; }
      moved++;
    });
    await audit("files_quarantined", { moved, skipped_changed: skippedChanged.length, skipped_missing: skippedMissing.length, failed: failed.length });
    return json({ ok: failed.length === 0, moved, skipped_changed: skippedChanged, skipped_missing: skippedMissing, failed });
  }

  if (action === "restore") {
    const { data: rows, error } = await admin.from("file_archive_log").select("path,trash_path").eq("bucket_id", bucket).eq("state", "quarantined");
    if (error) return json({ ok: false, error: error.message }, 500);
    const failed: { path: string; error: string }[] = [];
    let restored = 0;
    await pool(rows || [], 6, async (r) => {
      const m = await st.move(r.trash_path as string, r.path);
      if (m.error) { failed.push({ path: r.path, error: m.error.message }); return; }
      const u = await admin.from("file_archive_log").update({ state: "downloaded", trash_path: null, quarantined_at: null }).eq("bucket_id", bucket).eq("path", r.path);
      if (u.error) { failed.push({ path: r.path, error: "أُعيد الملف لكن تعذر تسجيله: " + u.error.message }); return; }
      restored++;
    });
    await audit("files_restored", { restored, failed: failed.length });
    return json({ ok: failed.length === 0, restored, failed });
  }

  if (action === "remove") {
    const { data: rows, error } = await admin.from("file_archive_log").select("path,trash_path").eq("bucket_id", bucket).eq("state", "quarantined");
    if (error) return json({ ok: false, error: error.message }, 500);
    const list = rows || [];
    const failed: { path: string; error: string }[] = [];
    let removed = 0;
    for (let i = 0; i < list.length; i += 50) {
      const chunk = list.slice(i, i + 50);
      const r = await st.remove(chunk.map((x) => x.trash_path as string));
      if (r.error) { chunk.forEach((x) => failed.push({ path: x.path, error: r.error!.message })); continue; }
      const gone = new Set((r.data || []).map((o: { name: string }) => o.name));
      for (const x of chunk) {
        if (!gone.has(x.trash_path as string)) { failed.push({ path: x.path, error: "لم يؤكد التخزين إزالة الملف" }); continue; }
        const u = await admin.from("file_archive_log").update({ state: "removed", removed_at: new Date().toISOString() }).eq("bucket_id", bucket).eq("path", x.path);
        if (u.error) failed.push({ path: x.path, error: "أُزيل الملف لكن تعذر تسجيله: " + u.error.message }); else removed++;
      }
    }
    await audit("files_removed", { removed, failed: failed.length });
    return json({ ok: failed.length === 0, removed, failed });
  }

  return json({ ok: false, error: "إجراء غير معروف" }, 400);
});
