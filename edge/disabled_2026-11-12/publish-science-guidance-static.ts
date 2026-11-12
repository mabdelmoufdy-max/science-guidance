import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const SOURCE_URL = "https://xehjwzszhsaqdqmcatum.supabase.co/functions/v1/science-guidance-data-form";
const BUCKET = "science-guidance-public";
const FILE = "index.html";

Deno.serve(async (req: Request) => {
  if (req.method !== "GET") return new Response("Method Not Allowed", { status: 405 });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const secretKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
    const secret = secretKeys.default || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!secret) throw new Error("Missing Supabase secret key");
    const admin = createClient(url, secret, { auth: { persistSession: false } });

    const srcRes = await fetch(SOURCE_URL, { headers: { "cache-control": "no-cache" } });
    if (!srcRes.ok) throw new Error(`Source fetch failed: ${srcRes.status}`);
    const html = await srcRes.text();
    if (!html.includes("<!doctype html") || !html.includes("نموذج جمع بيانات نظام توجيه العلوم")) {
      throw new Error("Unexpected source content");
    }

    const { data: bucketData, error: getErr } = await admin.storage.getBucket(BUCKET);
    if (getErr || !bucketData) {
      const { error: createErr } = await admin.storage.createBucket(BUCKET, {
        public: true,
        allowedMimeTypes: ["text/html"],
        fileSizeLimit: 1048576,
      });
      if (createErr && !String(createErr.message || createErr).toLowerCase().includes("already")) throw createErr;
    } else if (!bucketData.public) {
      const { error: updateErr } = await admin.storage.updateBucket(BUCKET, {
        public: true,
        allowedMimeTypes: ["text/html"],
        fileSizeLimit: 1048576,
      });
      if (updateErr) throw updateErr;
    }

    const blob = new Blob([html], { type: "text/html;charset=utf-8" });
    const { error: uploadErr } = await admin.storage.from(BUCKET).upload(FILE, blob, {
      contentType: "text/html; charset=utf-8",
      cacheControl: "60",
      upsert: true,
    });
    if (uploadErr) throw uploadErr;

    const publicUrl = `${url}/storage/v1/object/public/${BUCKET}/${FILE}?v=${Date.now()}`;
    return Response.json({ success: true, publicUrl });
  } catch (e) {
    console.error(e);
    return Response.json({ success: false, error: e instanceof Error ? e.message : String(e) }, { status: 500 });
  }
});
