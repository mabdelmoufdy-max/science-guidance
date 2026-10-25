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

function txt(v: unknown, max = 200) {
  return String(v ?? "").trim().slice(0, max);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!url || !serviceKey) return json({ error: "تعذر تهيئة خدمة الانتداب" }, 500);
  if (!token) return json({ error: "Unauthorized" }, 401);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);
  const actorId = userData.user.id;

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "صيغة الطلب غير صحيحة" }, 400); }

  const requestedRole = txt(req.headers.get("x-app-role") || body.role, 50);
  const allowed = new Set(["admin", "first_supervisor", "supervisor", "senior_teacher"]);
  if (!allowed.has(requestedRole)) return json({ error: "لا توجد صلاحية لتنفيذ الانتداب" }, 403);

  const { data: roleRow, error: roleError } = await admin
    .from("user_roles")
    .select("role")
    .eq("profile_id", actorId)
    .eq("role", requestedRole)
    .eq("is_active", true)
    .maybeSingle();
  if (roleError || !roleRow) return json({ error: "الدور الحالي غير مفعل لهذا الحساب" }, 403);

  let seniorHomeSchoolId: string | null = null;
  let supervisorId: string | null = null;
  if (requestedRole === "senior_teacher") {
    const { data: selfTeacher, error } = await admin
      .from("teacher_records")
      .select("id,home_school_id,is_senior_teacher,active")
      .eq("profile_id", actorId)
      .eq("active", true)
      .maybeSingle();
    if (error || !selfTeacher?.is_senior_teacher || !selfTeacher.home_school_id) {
      return json({ error: "لا توجد مدرسة مرتبطة بحساب مشرف المادة" }, 403);
    }
    seniorHomeSchoolId = String(selfTeacher.home_school_id);
  }
  if (requestedRole === "supervisor") {
    const { data: sup, error } = await admin
      .from("supervisors")
      .select("id")
      .eq("profile_id", actorId)
      .eq("active", true)
      .maybeSingle();
    if (error || !sup?.id) return json({ error: "لا يوجد سجل موجه نشط لهذا الحساب" }, 403);
    supervisorId = String(sup.id);
  }

  async function canTouchSchoolPair(fromId: string, toId: string) {
    if (requestedRole === "admin" || requestedRole === "first_supervisor") return true;
    if (requestedRole === "senior_teacher") return fromId === seniorHomeSchoolId || toId === seniorHomeSchoolId;
    if (requestedRole === "supervisor") {
      const { count, error } = await admin
        .from("schools")
        .select("id", { count: "exact", head: true })
        .eq("supervisor_id", supervisorId)
        .in("id", [fromId, toId]);
      return !error && Number(count || 0) > 0;
    }
    return false;
  }

  const action = txt(body.action || "create", 40);
  if (action === "options") {
    const teacherId = txt(body.teacher_id, 100);
    if (!teacherId) return json({ error: "حدد المعلم أولًا" }, 400);
    const { data: teacher, error: teacherError } = await admin
      .from("teacher_records")
      .select("id,full_name,civil_id,home_school_id,active")
      .eq("id", teacherId)
      .maybeSingle();
    if (teacherError || !teacher?.active || !teacher.home_school_id) return json({ error: "المعلم غير موجود أو غير نشط" }, 404);
    const fromId = String(teacher.home_school_id);
    const { data: fromSchool } = await admin.from("schools").select("id,name,stage").eq("id", fromId).maybeSingle();
    const { data: schools, error: schoolsError } = await admin.from("schools").select("id,name,stage").order("name");
    if (schoolsError) return json({ error: "تعذر تحميل المدارس" }, 500);
    if (requestedRole === "senior_teacher" && fromId !== seniorHomeSchoolId) {
      return json({ error: "يمكن لمشرف المادة بدء انتداب معلمي مدرسته فقط من هذه الشاشة" }, 403);
    }
    if (requestedRole === "supervisor") {
      const { data: owned } = await admin.from("schools").select("id").eq("supervisor_id", supervisorId);
      const ownedSet = new Set((owned || []).map((s) => String(s.id)));
      if (!ownedSet.has(fromId)) return json({ error: "المعلم لا يتبع مدرسة ضمن نطاق الموجه" }, 403);
    }
    return json({
      teacher: { id: teacher.id, full_name: teacher.full_name, civil_id: teacher.civil_id, home_school_id: fromId, home_school_name: fromSchool?.name || "" },
      schools: (schools || []).filter((s) => String(s.id) !== fromId),
    });
  }

  if (action !== "create") return json({ error: "إجراء غير مدعوم" }, 400);

  const teacherId = txt(body.teacher_id, 100);
  const toSchoolId = txt(body.to_school_id, 100);
  const delegationType = txt(body.delegation_type, 20);
  const startDate = txt(body.start_date, 20);
  const endDate = txt(body.end_date, 20) || null;
  const academicYearId = txt(body.academic_year_id, 100);
  const termId = txt(body.term_id, 100);
  if (!teacherId || !toSchoolId || !["partial", "full"].includes(delegationType) || !startDate || !academicYearId || !termId) {
    return json({ error: "بيانات الانتداب غير مكتملة" }, 400);
  }
  if (endDate && endDate < startDate) return json({ error: "تاريخ نهاية الانتداب يسبق تاريخ البداية" }, 400);

  const [{ data: teacher, error: teacherError }, { data: term, error: termError }] = await Promise.all([
    admin.from("teacher_records").select("id,full_name,civil_id,home_school_id,active").eq("id", teacherId).maybeSingle(),
    admin.from("terms").select("id,academic_year_id").eq("id", termId).eq("academic_year_id", academicYearId).maybeSingle(),
  ]);
  if (teacherError || !teacher?.active || !teacher.home_school_id) return json({ error: "المعلم غير موجود أو غير نشط" }, 404);
  if (termError || !term) return json({ error: "الفترة الدراسية لا تتبع العام المحدد" }, 400);

  const fromSchoolId = String(teacher.home_school_id);
  if (fromSchoolId === toSchoolId) return json({ error: "لا يمكن الانتداب إلى المدرسة الأصلية نفسها" }, 400);
  if (!(await canTouchSchoolPair(fromSchoolId, toSchoolId))) return json({ error: "الانتداب لا يتضمن مدرسة ضمن نطاق صلاحيتك" }, 403);

  const [{ data: fromSchool }, { data: toSchool }] = await Promise.all([
    admin.from("schools").select("id,name,stage").eq("id", fromSchoolId).maybeSingle(),
    admin.from("schools").select("id,name,stage").eq("id", toSchoolId).maybeSingle(),
  ]);
  if (!fromSchool || !toSchool) return json({ error: "إحدى المدرستين غير موجودة" }, 404);

  const { data: activeDelegations, error: existingError } = await admin
    .from("delegations")
    .select("id,start_date,end_date,to_school_id,delegation_type")
    .eq("teacher_id", teacherId)
    .eq("active", true);
  if (existingError) return json({ error: "تعذر التحقق من الانتدابات الحالية" }, 500);
  const newEnd = endDate || "9999-12-31";
  const overlap = (activeDelegations || []).find((d) => String(d.start_date) <= newEnd && startDate <= String(d.end_date || "9999-12-31"));
  if (overlap) return json({ error: "يوجد انتداب نشط متداخل زمنيًا لهذا المعلم" }, 409);

  const { data: created, error: createError } = await admin
    .from("delegations")
    .insert({
      teacher_id: teacherId,
      delegation_type: delegationType,
      from_school_id: fromSchoolId,
      to_school_id: toSchoolId,
      start_date: startDate,
      end_date: endDate,
      active: true,
    })
    .select("id,teacher_id,delegation_type,from_school_id,to_school_id,start_date,end_date,active")
    .single();
  if (createError || !created) return json({ error: createError?.message || "تعذر حفظ الانتداب" }, 500);

  const sourceAssignment = {
    teacher_id: teacherId,
    school_id: fromSchoolId,
    academic_year_id: academicYearId,
    term_id: termId,
    is_home_school: true,
    active: delegationType === "partial",
  };
  const targetAssignment = {
    teacher_id: teacherId,
    school_id: toSchoolId,
    academic_year_id: academicYearId,
    term_id: termId,
    is_home_school: false,
    active: true,
  };
  const [{ error: sourceAssignError }, { error: targetAssignError }] = await Promise.all([
    admin.from("teacher_school_assignments").upsert(sourceAssignment, { onConflict: "teacher_id,school_id,term_id" }),
    admin.from("teacher_school_assignments").upsert(targetAssignment, { onConflict: "teacher_id,school_id,term_id" }),
  ]);
  if (sourceAssignError || targetAssignError) {
    await admin.from("delegations").delete().eq("id", created.id);
    return json({ error: sourceAssignError?.message || targetAssignError?.message || "تعذر تحديث مدارس عمل المعلم" }, 500);
  }

  await admin.from("audit_log").insert({
    actor_profile_id: actorId,
    actor_role: requestedRole,
    action: "execute_teacher_delegation",
    entity_type: "delegation",
    entity_id: String(created.id),
    new_data: {
      teacher_id: teacherId,
      teacher_name: teacher.full_name,
      delegation_type: delegationType,
      from_school_id: fromSchoolId,
      from_school_name: fromSchool.name,
      to_school_id: toSchoolId,
      to_school_name: toSchool.name,
      start_date: startDate,
      end_date: endDate,
      executed_directly: true,
    },
  });

  return json({
    success: true,
    delegation: created,
    teacher_name: teacher.full_name,
    from_school_name: fromSchool.name,
    to_school_name: toSchool.name,
    delegation_type: delegationType,
  });
});
