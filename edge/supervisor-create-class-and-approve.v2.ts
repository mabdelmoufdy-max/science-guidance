import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-app-role",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });
}

function text(value: unknown, max = 160) {
  return String(value ?? "").trim().slice(0, max);
}

function normalizeArabic(value: unknown) {
  return text(value, 240)
    .normalize("NFKC")
    .replace(/[ً-ٰٟۖ-ۭ]/g, "")
    .replace(/ـ/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .toLocaleLowerCase("ar");
}

function nonNegativeInteger(value: unknown) {
  if (value === null || value === undefined || value === "") return null;
  const n = Number(value);
  return Number.isInteger(n) && n >= 0 ? n : null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!url || !serviceKey) return json({ error: "تعذر تهيئة خدمة حفظ الفصل" }, 500);
  if (!token) return json({ error: "Unauthorized" }, 401);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);
  const actorId = userData.user.id;

  const [{ data: profile, error: profileError }, { data: roleRow, error: roleError }] = await Promise.all([
    admin.from("profiles").select("id,full_name,is_active").eq("id", actorId).maybeSingle(),
    admin.from("user_roles").select("role").eq("profile_id", actorId).eq("role", "supervisor").eq("is_active", true).maybeSingle(),
  ]);
  if (profileError || !profile?.is_active) return json({ error: "الحساب غير مفعل" }, 403);
  if (roleError || !roleRow) return json({ error: "هذه العملية متاحة للمشرف المكلّف فقط" }, 403);


  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "صيغة الطلب غير صحيحة" }, 400);
  }

  const requestedSchoolId = text(body.school_id, 100);
  const requestedSchoolName = text(body.school_name, 240);
  const academicYearId = text(body.academic_year_id, 100);
  const termId = text(body.term_id, 100);
  const input = body.class && typeof body.class === "object" ? body.class as Record<string, unknown> : {};

  if (!academicYearId || !termId) return json({ error: "يلزم تحديد السنة والفترة الدراسية" }, 400);

  const [{ data: supervisor, error: supervisorError }, { data: term, error: termError }] = await Promise.all([
    admin.from("supervisors").select("id").eq("profile_id", actorId).eq("active", true).maybeSingle(),
    admin.from("terms").select("id,academic_year_id,is_active").eq("id", termId).eq("academic_year_id", academicYearId).eq("is_active", true).maybeSingle(),
  ]);
  if (supervisorError || !supervisor?.id) return json({ error: "لا يوجد سجل مشرف نشط لهذا الحساب" }, 403);
  if (termError || !term) return json({ error: "الفترة الدراسية غير مفعلة أو لا تتبع السنة المحددة" }, 400);

  const { data: ownedSchools, error: schoolsError } = await admin
    .from("schools")
    .select("id,name,stage,supervisor_id,class_count,status")
    .eq("supervisor_id", supervisor.id)
    .order("name");
  if (schoolsError) return json({ error: schoolsError.message || "تعذر قراءة مدارس المشرف" }, 500);

  const schools = ownedSchools || [];
  let school = requestedSchoolId ? schools.find((s) => String(s.id) === requestedSchoolId) : undefined;
  if (!school && requestedSchoolName) {
    const wanted = normalizeArabic(requestedSchoolName);
    const matches = schools.filter((s) => normalizeArabic(s.name) === wanted);
    if (matches.length === 1) school = matches[0];
  }

  if (!school) {
    return json({
      error: "المدرسة غير موجودة ضمن المدارس المسندة لهذا المشرف. لم يتم إنشاء مدرسة جديدة.",
      requested_school_id: requestedSchoolId || null,
      requested_school_name: requestedSchoolName || null,
    }, 404);
  }

  const schoolId = String(school.id);
  const stage = text(input.stage, 40);
  const grade = text(input.grade, 80);
  const className = text(input.class_name, 120);
  const leaderTeacherId = text(input.leader_teacher_id, 100) || null;
  const gradeOrderRaw = input.grade_order;
  const gradeOrder = nonNegativeInteger(gradeOrderRaw);

  if (!stage || !grade || !className) return json({ error: "المرحلة والصف واسم الفصل مطلوبة" }, 400);
  if (stage !== String(school.stage || "")) return json({ error: "مرحلة الفصل يجب أن تطابق مرحلة المدرسة" }, 400);
  if (gradeOrderRaw !== null && gradeOrderRaw !== undefined && gradeOrderRaw !== "" && gradeOrder === null) {
    return json({ error: "ترتيب الصف غير صحيح" }, 400);
  }

  if (leaderTeacherId) {
    const { data: leader, error: leaderError } = await admin
      .from("teacher_records")
      .select("id,home_school_id,active")
      .eq("id", leaderTeacherId)
      .maybeSingle();
    if (leaderError || !leader?.active || String(leader.home_school_id) !== schoolId) {
      return json({ error: "رائد الفصل يجب أن يكون معلمًا نشطًا في المدرسة نفسها" }, 400);
    }
  }

  const { data: existingClass, error: existingClassError } = await admin
    .from("school_classes")
    .select("id")
    .eq("school_id", schoolId)
    .eq("academic_year_id", academicYearId)
    .eq("term_id", termId)
    .eq("grade", grade)
    .eq("class_name", className)
    .maybeSingle();
  if (existingClassError) return json({ error: existingClassError.message || "تعذر التحقق من تكرار الفصل" }, 500);
  if (existingClass?.id) return json({ error: "هذا الفصل مسجل بالفعل لهذه الفترة الدراسية" }, 409);

  const { data: createdClass, error: createClassError } = await admin
    .from("school_classes")
    .insert({
      school_id: schoolId,
      academic_year_id: academicYearId,
      term_id: termId,
      stage,
      grade,
      class_name: className,
      science_periods: 0,
      grade_order: gradeOrder,
      leader_teacher_id: leaderTeacherId,
    })
    .select("id,school_id,stage,grade,class_name")
    .single();
  if (createClassError || !createdClass) return json({ error: createClassError?.message || "تعذر حفظ الفصل" }, 500);

  const [{ count: detailedClasses, error: countError }, { data: existingSubmission, error: submissionReadError }] = await Promise.all([
    admin.from("school_classes").select("id", { count: "exact", head: true }).eq("school_id", schoolId).eq("term_id", termId),
    admin.from("school_submissions").select("id,row_version").eq("school_id", schoolId).eq("term_id", termId).maybeSingle(),
  ]);
  if (countError || submissionReadError) {
    return json({ error: countError?.message || submissionReadError?.message || "تم حفظ الفصل لكن تعذر تحديث الاعتماد" }, 500);
  }

  const now = new Date().toISOString();
  const submissionPatch = {
    status: "approved",
    submitted_by: actorId,
    submitted_at: now,
    approved_by: actorId,
    approved_at: now,
    return_reason: null,
    entry_source: "supervisor",
    intervention_reason: "إضافة فصل جديد وحفظه واعتماده مباشرة بواسطة المشرف المكلّف بالمدرسة",
    last_changed_by: actorId,
    updated_at: now,
  };

  let submission: { id: string; row_version: number } | null = null;
  if (existingSubmission?.id) {
    const { data, error } = await admin
      .from("school_submissions")
      .update({ ...submissionPatch, row_version: Number(existingSubmission.row_version || 0) + 1 })
      .eq("id", existingSubmission.id)
      .select("id,row_version")
      .single();
    if (error) return json({ error: error.message }, 500);
    submission = data;
  } else {
    const { data, error } = await admin
      .from("school_submissions")
      .insert({ school_id: schoolId, academic_year_id: academicYearId, term_id: termId, ...submissionPatch, row_version: 1 })
      .select("id,row_version")
      .single();
    if (error) return json({ error: error.message }, 500);
    submission = data;
  }

  const declaredClasses = Math.max(Number(school.class_count || 0), Number(detailedClasses || 0));
  const { error: schoolUpdateError } = await admin
    .from("schools")
    .update({ status: "approved", class_count: declaredClasses })
    .eq("id", schoolId);
  if (schoolUpdateError) return json({ error: schoolUpdateError.message }, 500);

  await admin.from("audit_log").insert({
    actor_profile_id: actorId,
    actor_role: "supervisor",
    action: "supervisor_create_class_and_direct_approve",
    entity_type: "school_submission",
    entity_id: submission?.id || null,
    new_data: {
      school_id: schoolId,
      school_name: school.name,
      class_id: createdClass.id,
      class_name: createdClass.class_name,
      grade: createdClass.grade,
      detailed_classes: Number(detailedClasses || 0),
      matched_existing_school_only: true,
    },
  });

  return json({
    success: true,
    school_id: schoolId,
    school_name: school.name,
    class: createdClass,
    submission_id: submission?.id,
    row_version: submission?.row_version,
    detailed_classes: Number(detailedClasses || 0),
    declared_classes: declaredClasses,
    status: "approved",
  });
});
